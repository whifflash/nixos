{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf mkOption types optionalString;

  cfg = config.services.giteaSync;

  user = config.system.primaryUser;

  home =
    let
      h = config.users.users.${user}.home or null;
    in
    if h == null then "/Users/${user}" else h;

  hmCfg = config.home-manager.users.${user};

  giteaHostFromBaseUrl =
    let
      m = builtins.match "^https?://([^/]+).*$" cfg.baseUrl;
    in
    if m == null then cfg.baseUrl else builtins.elemAt m 0;

  envFile = "${home}/.config/sops-nix/templates/gitea.env";

  giteaSyncScript =
    pkgs.writeShellScript "gitea-sync-user-repos.sh"
    (builtins.readFile ../../scripts/gitea-sync-user-repos.sh);

  runLog = "${home}/Library/Logs/gitea-sync-run.log";

  # Dedicated SSH config used *only* for this job. It reuses your existing
  # trust store (known_hosts) but makes host/port and options deterministic.
  #
  # Note: "Host git.c4rb0n.cloud" matches clone URLs that use the hostname.
  # If some repos use the IP in the URL, add a second Host stanza below.
  sshConfig = pkgs.writeText "gitea-sync-ssh_config" ''
    Host git.c4rb0n.cloud
      HostName ${cfg.sshHostName}
      Port ${toString cfg.sshPort}
      User git
      BatchMode yes
      StrictHostKeyChecking yes
      UserKnownHostsFile ${cfg.knownHostsFile}
      ConnectTimeout 10
      ConnectionAttempts 1
      IdentitiesOnly no

    Host 10.20.31.41
      HostName 10.20.31.41
      Port ${toString cfg.sshPort}
      User git
      BatchMode yes
      StrictHostKeyChecking yes
      UserKnownHostsFile ${cfg.knownHostsFile}
      ConnectTimeout 10
      ConnectionAttempts 1
      IdentitiesOnly no
  '';

  wrapper = pkgs.writeShellScriptBin "gitea-sync-run" ''
    set -euo pipefail

    ts="$(${pkgs.coreutils}/bin/date -Iseconds)"
    start_epoch="$(${pkgs.coreutils}/bin/date +%s)"
    rc=0

    {
      echo "===== gitea-sync run start: $ts ====="
      echo "BASE_URL=''${BASE_URL:-}"
      echo "DEST_DIR=''${DEST_DIR:-}"
      echo "STATE_DIR=''${STATE_DIR:-}"
      echo "LOG_LEVEL=''${LOG_LEVEL:-}"
      echo "KNOWN_HOSTS_FILE=''${KNOWN_HOSTS_FILE:-}"
      echo "GIT_SSH_COMMAND=''${GIT_SSH_COMMAND:-}"
      echo "SSH_CONFIG=${sshConfig}"
      echo "PATH=''${PATH:-}"
      echo "HOME=''${HOME:-} USER=''${USER:-} EUID=$(${pkgs.coreutils}/bin/id -u)"
    } >> "${runLog}"

    finish() {
      end_epoch="$(${pkgs.coreutils}/bin/date +%s)"
      dur="$((end_epoch - start_epoch))"
      {
        echo "wrapper_exit_code=$rc duration_sec=$dur"
        echo "===== gitea-sync run end: $ts rc=$rc ====="
      } >> "${runLog}"
    }
    trap 'rc=$?; finish' EXIT

    ${optionalString (cfg.randomizedDelaySec != null) ''
      delay="${toString cfg.randomizedDelaySec}"
      if [ "$delay" -gt 0 ]; then
        d="$(${pkgs.coreutils}/bin/shuf -i 0-"$delay" -n 1)"
        echo "randomized_delay_sec=$d" >> "${runLog}"
        sleep "$d"
      fi
    ''}

    install -m 700 -d "${cfg.stateDir}"
    install -m 755 -d "${cfg.destDir}"

    if [ -f "${envFile}" ]; then
      # shellcheck disable=SC1090
      . "${envFile}"
    fi

    export TOKEN
    if [ -z "''${TOKEN:-}" ]; then
      echo "ERROR: TOKEN missing after sourcing ${envFile}" >> "${runLog}"
      exit 78
    fi

    if [ "''${GITEA_SYNC_TRACE:-0}" = "1" ]; then
      set -x
    fi

    echo "about_to_run_sync_script=1" >> "${runLog}"

    "${giteaSyncScript}" >> "${runLog}" 2>&1
  '';
in
{
  options.services.giteaSync = {
    enable = mkEnableOption "Sync repositories from Gitea (Darwin launchd user agent)";

    debug = mkOption {
      type = types.bool;
      default = false;
      description = "Enable debug logging and shell tracing for gitea-sync.";
    };

    baseUrl = mkOption {
      type = types.str;
      default = "https://git.c4rb0n.cloud";
      description = "Base URL of the Gitea instance.";
    };

    giteaHost = mkOption {
      type = types.str;
      default = giteaHostFromBaseUrl;
      description = "Host used for SSH operations; defaults to the host parsed from baseUrl.";
    };

    destDir = mkOption {
      type = types.str;
      default = "${home}/git/${giteaHostFromBaseUrl}";
      description = "Destination directory for checked out repositories.";
    };

    stateDir = mkOption {
      type = types.str;
      default = "${home}/Library/ApplicationSupport/gitea-sync";
      description = "State directory passed to the sync script as STATE_DIR.";
    };

    knownHostsFile = mkOption {
      type = types.str;
      default = "${home}/.ssh/known_hosts";
      description = "Known hosts file to use for SSH; reuses terminal trust to avoid drift.";
    };

    sshPort = mkOption {
      type = types.int;
      default = 2222;
      description = "SSH port for Gitea.";
    };

    # Canonical HostName for git.c4rb0n.cloud within the job.
    # Set to 10.20.31.41 to match your proven working path.
    sshHostName = mkOption {
      type = types.str;
      default = "10.20.31.41";
      description = "HostName used in the job-specific ssh_config for git.c4rb0n.cloud.";
    };

    startIntervalSec = mkOption {
      type = types.int;
      default = 3600;
      description = "Run interval in seconds (launchd StartInterval).";
    };

    randomizedDelaySec = mkOption {
      type = types.nullOr types.int;
      default = 600;
      description = "Random delay before each run (seconds).";
    };

    logLevel = mkOption {
      type = types.str;
      default = "INFO";
      description = "LOG_LEVEL passed to the sync script.";
    };

    tokenSopsFile = mkOption {
      type = types.path;
      default = ../../secrets/gitea-token.yaml;
      description = "SOPS YAML file containing the Gitea token (key: token).";
    };
  };

  config = mkIf cfg.enable {
    home-manager.sharedModules = [
      inputs.sops-nix.homeManagerModules.sops
    ];

    home-manager.users.${user}.sops = {
      age.keyFile = "${home}/.config/sops/age/keys.txt";

      secrets."gitea/token" = {
        sopsFile = cfg.tokenSopsFile;
        format = "yaml";
        key = "token";
        mode = "0400";
      };

      templates."gitea.env" = {
        content = ''
          TOKEN=${hmCfg.sops.placeholder."gitea/token"}
        '';
        path = envFile;
        mode = "0400";
      };
    };

    environment.systemPackages = with pkgs; [
      coreutils
      curl
      git
      jq
      openssh
      gnused
    ];

    launchd.user.agents.gitea-sync = {
      serviceConfig = {
        ProgramArguments = [ "${wrapper}/bin/gitea-sync-run" ];

        RunAtLoad = true;
        StartInterval = cfg.startIntervalSec;

        StandardOutPath = "${home}/Library/Logs/gitea-sync.log";
        StandardErrorPath = "${home}/Library/Logs/gitea-sync.err.log";

        ExitTimeOut = 300;

        EnvironmentVariables = {
          BASE_URL = cfg.baseUrl;
          DEST_DIR = cfg.destDir;

          STATE_DIR = cfg.stateDir;
          STATE_DIRECTORY = cfg.stateDir;

          LOG_LEVEL = if cfg.debug then "DEBUG" else cfg.logLevel;

          KNOWN_HOSTS_FILE = cfg.knownHostsFile;

          # Non-interactive.
          GIT_TERMINAL_PROMPT = "0";
          SSH_ASKPASS = "/usr/bin/false";
          SSH_ASKPASS_REQUIRE = "force";

          # Use a dedicated ssh_config to make host/port/known_hosts deterministic.
          GIT_SSH_COMMAND = "ssh -F ${sshConfig}";

          # Optional bash tracing (very noisy).
          GITEA_SYNC_TRACE = if cfg.debug then "1" else "0";

          PATH =
            lib.makeBinPath [
              pkgs.coreutils
              pkgs.curl
              pkgs.git
              pkgs.jq
              pkgs.openssh
              pkgs.gnused
            ]
            + ":/usr/bin:/bin:/usr/sbin:/sbin";
        };
      };
    };
  };
}
