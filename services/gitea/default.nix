{
  config,
  lib,
  ...
}: let
  cfg = config.infra.services.gitea;
  hostName =
    if cfg.hostName != null
    then cfg.hostName
    else "git.${config.infra.domain}";
in {
  options.infra.services.gitea = {
    enable = lib.mkEnableOption "the shared Gitea service";

    hostName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "git.example.com";
      description = "Public DNS name for Gitea. Defaults to git.<infra.domain>.";
    };

    httpPort = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Loopback HTTP port used between Nginx and Gitea.";
    };

    sshPort = lib.mkOption {
      type = lib.types.port;
      default = 2222;
      description = "TCP port exposed by Gitea's built-in SSH server.";
    };

    disableRegistration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether self-service account registration is disabled.";
    };
  };

  config = lib.mkIf cfg.enable {
    infra.acme.enable = true;

    sops.secrets = {
      "restic/gitea/repository_password" = {
        sopsFile = ../../secrets/infrastructure.yaml;
        key = "restic/gitea/repository_password";
        format = "yaml";
        mode = "0400";
      };

      "restic/gitea/environment" = {
        sopsFile = ../../secrets/infrastructure.yaml;
        key = "restic/gitea/environment";
        format = "yaml";
        mode = "0400";
      };
    };

    security.acme.certs.${hostName} = {};

    services = {
      gitea = {
        enable = true;
        database.type = "sqlite3";
        lfs.enable = true;

        dump = {
          enable = true;
          interval = "03:15";
          backupDir = "/var/backup/gitea";
          type = "tar.zst";
        };

        settings = {
          server = {
            DOMAIN = hostName;
            ROOT_URL = "https://${hostName}/";
            PROTOCOL = "http";
            HTTP_ADDR = "127.0.0.1";
            HTTP_PORT = cfg.httpPort;

            START_SSH_SERVER = true;
            BUILTIN_SSH_SERVER_USER = "git";
            SSH_USER = "git";
            SSH_DOMAIN = hostName;
            SSH_LISTEN_HOST = "0.0.0.0";
            SSH_LISTEN_PORT = cfg.sshPort;
            SSH_PORT = cfg.sshPort;
          };

          service.DISABLE_REGISTRATION = cfg.disableRegistration;
          session.COOKIE_SECURE = true;
        };
      };

      nginx = {
        enable = true;
        recommendedGzipSettings = true;
        recommendedProxySettings = true;
        recommendedTlsSettings = true;

        virtualHosts.${hostName} = {
          useACMEHost = hostName;
          forceSSL = true;

          extraConfig = ''
            client_max_body_size 512M;
          '';

          locations."/" = {
            proxyPass = "http://127.0.0.1:${toString cfg.httpPort}";
            proxyWebsockets = true;
          };
        };
      };

      restic.backups.gitea = {
        repository = "rest:https://restic.c4rb0n.cloud/restic-gitea";

        passwordFile =
          config.sops.secrets."restic/gitea/repository_password".path;

        environmentFile =
          config.sops.secrets."restic/gitea/environment".path;

        paths = [
          "/var/lib/gitea"
        ];

        initialize = true;

        backupPrepareCommand = ''
          systemctl stop gitea.service
        '';

        backupCleanupCommand = ''
          systemctl start gitea.service
        '';

        timerConfig = {
          OnCalendar = "04:00";
          Persistent = true;
          RandomizedDelaySec = "15m";
        };

        pruneOpts = [
          "--keep-daily 7"
          "--keep-weekly 5"
          "--keep-monthly 12"
          "--keep-yearly 3"
          "--group-by host,paths"
        ];
      };

      # restic.backups.gitea = {
      #   repository = "rest:https://restic.c4rb0n.cloud/restic-gitea";

      #   passwordFile =
      #     config.sops.secrets."restic/gitea/repository_password".path;

      #   environmentFile =
      #     config.sops.secrets."restic/gitea/environment".path;

      #   paths = [
      #     "/var/lib/gitea"
      #   ];

      #   initialize = true;
      # };
    };

    networking.firewall.allowedTCPPorts = [
      80
      443
      cfg.sshPort
    ];
  };
}
