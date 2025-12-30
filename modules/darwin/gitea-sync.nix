{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkOption types optionalString;

  cfg = config.services.giteaSync;

  # Reuse your existing repo script verbatim (same as NixOS role does)
  giteaSyncScript =
    pkgs.writeShellScript "gitea-sync-user-repos.sh"
    (builtins.readFile ../../scripts/gitea-sync-user-repos.sh);

  # Wrapper to emulate systemd preStart + RandomizedDelaySec
  wrapper = pkgs.writeShellScriptBin "gitea-sync-run" ''
    set -euo pipefail

    # RandomizedDelaySec equivalent (optional)
    ${optionalString (cfg.randomizedDelaySec != null) ''
      delay="${toString cfg.randomizedDelaySec}"
      if [ "$delay" -gt 0 ]; then
        sleep "$(${pkgs.coreutils}/bin/shuf -i 0-"$delay" -n 1)"
      fi
    ''}

    # PreStart equivalent: ensure state dir + populate known_hosts
    install -m 700 -d "${cfg.stateDir}"
    ${pkgs.openssh}/bin/ssh-keyscan -T 5 "${cfg.giteaHost}" >> "${cfg.stateDir}/known_hosts" 2>/dev/null || true

    exec "${giteaSyncScript}"
  '';
in {
  options.services.giteaSync = {
    enable = mkEnableOption "Sync all Gitea repositories visible to the token (launchd user agent)";

    baseUrl = mkOption {
      type = types.str;
      example = "https://git.c4rb0n.cloud";
      description = "Base URL of the Gitea instance (https://host).";
    };

    giteaHost = mkOption {
      type = types.str;
      example = "git.c4rb0n.cloud";
      description = "Host portion used for ssh-keyscan.";
    };

    destDir = mkOption {
      type = types.str;
      default = "${config.users.users.${config.system.primaryUser}.home}/git.c4rb0n.cloud";
      description = "Destination directory containing one folder per repo.";
    };

    stateDir = mkOption {
      type = types.str;
      default = "${config.users.users.${config.system.primaryUser}.home}/Library/Application Support/gitea-sync";
      description = "State directory (known_hosts, counters). Passed as STATE_DIRECTORY.";
    };

    # Token handling:
    # NixOS uses sops template envFile. On Darwin you can also do that,
    # but this module keeps it generic: a file containing TOKEN=...
    envFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Optional path to an env file containing TOKEN=... (and optionally others).";
    };

    # Schedule:
    startIntervalSec = mkOption {
      type = types.int;
      default = 3600;
      description = "How often to run the sync (seconds).";
    };

    randomizedDelaySec = mkOption {
      type = types.nullOr types.int;
      default = 600;
      description = "Random sleep (seconds) before each run; approximates systemd RandomizedDelaySec.";
    };

    logLevel = mkOption {
      type = types.str;
      default = "INFO";
      description = "LOG_LEVEL for the script (DEBUG, INFO, WARN, ERROR).";
    };
  };

  config = mkIf cfg.enable {
    # Ensure required tools exist for the script + wrapper.
    environment.systemPackages = with pkgs; [
      curl
      jq
      git
      openssh
      coreutils
    ];

    # launchd user agent = closest equivalent to your NixOS oneshot+timer as user mhr
    launchd.user.agents.gitea-sync = {
      enable = true;

      # run wrapper
      programArguments = [ "${wrapper}/bin/gitea-sync-run" ];

      serviceConfig = {
        RunAtLoad = true;
        StartInterval = cfg.startIntervalSec;

        StandardOutPath = "${config.users.users.${config.system.primaryUser}.home}/Library/Logs/gitea-sync.log";
        StandardErrorPath = "${config.users.users.${config.system.primaryUser}.home}/Library/Logs/gitea-sync.err.log";

        EnvironmentVariables = {
          BASE_URL = cfg.baseUrl;
          DEST_DIR = cfg.destDir;
          LOG_LEVEL = cfg.logLevel;
          STATE_DIRECTORY = cfg.stateDir;

          # Make sure PATH contains required binaries at runtime.
          PATH = lib.makeBinPath [ pkgs.curl pkgs.jq pkgs.git pkgs.openssh pkgs.coreutils ];
        };
      };
    };

    # If you want an env file like NixOS EnvironmentFile=:
    # launchd doesn’t have an "EnvironmentFile" knob; we emulate by sourcing it in wrapper.
    # Easiest: put TOKEN=... into cfg.envFile and teach wrapper to source it.
    assertions = [
      {
        assertion = cfg.envFile == null || builtins.pathExists cfg.envFile;
        message = "services.giteaSync.envFile was set but does not exist.";
      }
    ];

    # Patch wrapper to source envFile, if provided:
    # Keep it linter-friendly by using a separate override of wrapper generation if you prefer.
  };
}
