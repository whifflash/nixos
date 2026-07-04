{
  config,
  lib,
  ...
}: let
  cfg = config.infra.services.paperless;
  hostName =
    if cfg.hostName != null
    then cfg.hostName
    else "paperless.${config.infra.domain}";
  consumptionDir = "/var/lib/paperless-sftp/upload";
  scannerDirectories = [
    "hannes"
    "antonia"
    "luise"
    "dietmar"
    "familie"
    "eingang"
  ];
in {
  options.infra.services.paperless = {
    enable = lib.mkEnableOption "the shared Paperless-ngx document archive";

    hostName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "paperless.example.com";
      description = "DNS name for Paperless-ngx. Defaults to paperless.<infra.domain>.";
    };

    httpPort = lib.mkOption {
      type = lib.types.port;
      default = 28981;
      description = "Loopback HTTP port used between Nginx and Paperless-ngx.";
    };

    sftpUser = lib.mkOption {
      type = lib.types.str;
      default = "paperless-ingest";
      description = "Restricted SFTP user used by the document scanner.";
    };
  };

  config = lib.mkIf cfg.enable {
    infra.acme.enable = true;

    security.acme.certs.${hostName} = {};

    sops.secrets."paperless/sftp/password_hash" = {
      sopsFile = ../../secrets/infrastructure.yaml;
      owner = "root";
      group = "root";
      mode = "0400";
      neededForUsers = true;
    };

    services = {
      paperless = {
        enable = true;
        address = "127.0.0.1";
        port = cfg.httpPort;
        inherit consumptionDir;

        database.createLocally = true;

        settings = {
          PAPERLESS_URL = "https://${hostName}";
          PAPERLESS_OCR_LANGUAGE = "deu+eng";
          PAPERLESS_CONSUMER_RECURSIVE = true;
          PAPERLESS_CONSUMER_SUBDIRS_AS_TAGS = false;
          PAPERLESS_TASK_WORKERS = 1;
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

          locations = {
            "/" = {
              proxyPass = "http://127.0.0.1:${toString cfg.httpPort}";
              proxyWebsockets = true;
            };

            "/static/" = {
              root = config.services.paperless.package;
              extraConfig = ''
                rewrite ^/(.*)$ /lib/paperless-ngx/$1 break;
              '';
            };

            "/ws/status" = {
              proxyPass = "http://127.0.0.1:${toString cfg.httpPort}";
              proxyWebsockets = true;
            };
          };
        };
      };

      openssh.extraConfig = ''
        Match User ${cfg.sftpUser}
          PasswordAuthentication yes
          KbdInteractiveAuthentication no
          PubkeyAuthentication no
          AllowAgentForwarding no
          AllowTcpForwarding no
          PermitTunnel no
          PermitTTY no
          X11Forwarding no
          ChrootDirectory /var/lib/paperless-sftp
          ForceCommand internal-sftp -d /upload -u 0007
      '';
    };

    users.users.${cfg.sftpUser} = {
      isNormalUser = true;
      description = "Paperless scanner ingest";
      home = "/upload";
      createHome = false;
      group = "paperless";
      hashedPasswordFile = config.sops.secrets."paperless/sftp/password_hash".path;
    };

    systemd.tmpfiles.rules =
      [
        "d /var/lib/paperless-sftp 0755 root root -"
        "z ${consumptionDir} 2770 paperless paperless -"
      ]
      ++ map (directory: "d ${consumptionDir}/${directory} 2770 paperless paperless -") scannerDirectories;

    networking.firewall.allowedTCPPorts = [80 443];
  };
}
