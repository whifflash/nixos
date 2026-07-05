{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.infra.services.ntfy;
  certificateName = "wildcard-${config.infra.domain}";
  hostName =
    if cfg.hostName != null
    then cfg.hostName
    else "ntfy.${config.infra.domain}";

  userType = lib.types.submodule ({name, ...}: {
    options = {
      passwordSecret = lib.mkOption {
        type = lib.types.str;
        default = "ntfy/users/${name}/password";
        description = "SOPS key containing this ntfy user's plaintext password.";
      };

      role = lib.mkOption {
        type = lib.types.enum ["user" "admin"];
        default = "user";
        description = "ntfy account role.";
      };

      access = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            topic = lib.mkOption {
              type = lib.types.str;
              description = "Topic name or wildcard pattern.";
            };

            permission = lib.mkOption {
              type = lib.types.enum [
                "deny-all"
                "read-only"
                "write-only"
                "read-write"
              ];
              description = "Permission granted on the topic.";
            };
          };
        });
        default = [];
        description = "Declaratively provisioned topic ACL entries.";
      };
    };
  });

  provisionUser = username: user: let
    credentialName = "password-${username}";
    accessCommands =
      lib.concatMapStringsSep "\n" (entry: ''
        ${pkgs.ntfy-sh}/bin/ntfy access \
          ${lib.escapeShellArg username} \
          ${lib.escapeShellArg entry.topic} \
          ${lib.escapeShellArg entry.permission}
      '')
      user.access;
  in ''
    password="$(${pkgs.coreutils}/bin/cat "$CREDENTIALS_DIRECTORY/${credentialName}")"

    if ${pkgs.ntfy-sh}/bin/ntfy user list \
      | ${pkgs.gnugrep}/bin/grep -Fq ${lib.escapeShellArg "user ${username} ("}; then
      NTFY_PASSWORD="$password" ${pkgs.ntfy-sh}/bin/ntfy user change-pass \
        ${lib.escapeShellArg username}
      ${pkgs.ntfy-sh}/bin/ntfy user change-role \
        ${lib.escapeShellArg username} \
        ${lib.escapeShellArg user.role}
    else
      NTFY_PASSWORD="$password" ${pkgs.ntfy-sh}/bin/ntfy user add \
        --role=${lib.escapeShellArg user.role} \
        ${lib.escapeShellArg username}
    fi

    ${pkgs.ntfy-sh}/bin/ntfy access \
      --reset \
      ${lib.escapeShellArg username}

    ${accessCommands}
  '';

  provisionScript = pkgs.writeShellApplication {
    name = "infra-ntfy-provision";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.ntfy-sh
    ];
    text = ''
      set -euo pipefail

      ${lib.concatStringsSep "\n" (lib.mapAttrsToList provisionUser cfg.users)}
    '';
  };
in {
  options.infra.services.ntfy = {
    enable = lib.mkEnableOption "the self-hosted ntfy notification service";

    hostName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "ntfy.example.com";
      description = "DNS name for ntfy. Defaults to ntfy.<infra.domain>.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 2586;
      description = "Loopback port used by ntfy and Nginx.";
    };

    topics = {
      critical = lib.mkOption {
        type = lib.types.str;
        default = "icarus-critical";
        description = "Topic used for critical infrastructure alerts.";
      };

      warning = lib.mkOption {
        type = lib.types.str;
        default = "icarus-warning";
        description = "Topic used for warning infrastructure alerts.";
      };

      info = lib.mkOption {
        type = lib.types.str;
        default = "icarus-info";
        description = "Topic used for informational infrastructure alerts.";
      };
    };

    users = lib.mkOption {
      type = lib.types.attrsOf userType;
      default = {
        alertmanager.access = [
          {
            topic = cfg.topics.critical;
            permission = "write-only";
          }
          {
            topic = cfg.topics.warning;
            permission = "write-only";
          }
          {
            topic = cfg.topics.info;
            permission = "write-only";
          }
        ];

        mhr.access = [
          {
            topic = cfg.topics.critical;
            permission = "read-only";
          }
          {
            topic = cfg.topics.warning;
            permission = "read-only";
          }
          {
            topic = cfg.topics.info;
            permission = "read-only";
          }
        ];
      };
      description = "ntfy users and their topic ACLs.";
    };
  };

  config = lib.mkIf cfg.enable {
    infra.acme.enable = true;

    security.acme.certs.${certificateName} = {
      domain = config.infra.domain;
      extraDomainNames = ["*.${config.infra.domain}"];
      group = "nginx";
    };

    sops.secrets = lib.mapAttrs' (_username: user:
      lib.nameValuePair user.passwordSecret {
        sopsFile = ../../secrets/infrastructure.yaml;
        key = user.passwordSecret;
        mode = "0400";
      })
    cfg.users;

    services = {
      ntfy-sh = {
        enable = true;
        settings = {
          base-url = "https://${hostName}";
          listen-http = "127.0.0.1:${toString cfg.port}";
          behind-proxy = true;
          auth-default-access = "deny-all";
          enable-login = true;
          enable-signup = false;
          upstream-base-url = "https://ntfy.sh";
        };
      };

      nginx = {
        enable = true;
        recommendedProxySettings = true;
        recommendedTlsSettings = true;

        virtualHosts.${hostName} = {
          useACMEHost = certificateName;
          forceSSL = true;
          locations."/" = {
            proxyPass = "http://127.0.0.1:${toString cfg.port}";
            proxyWebsockets = true;
          };
        };
      };
    };

    systemd.services = {
      infra-ntfy-provision = {
        description = "Provision ntfy users and topic ACLs";
        before = ["ntfy-sh.service"];
        requiredBy = ["ntfy-sh.service"];
        serviceConfig = {
          Type = "oneshot";
          User = config.services.ntfy-sh.user;
          Group = config.services.ntfy-sh.group;
          ExecStart = "${provisionScript}/bin/infra-ntfy-provision";
          StateDirectory = "ntfy-sh";
          LoadCredential =
            lib.mapAttrsToList (username: user: "password-${username}:${config.sops.secrets.${user.passwordSecret}.path}")
            cfg.users;
        };
      };

      ntfy-sh = {
        after = ["infra-ntfy-provision.service"];
        requires = ["infra-ntfy-provision.service"];
      };
    };
  };
}
