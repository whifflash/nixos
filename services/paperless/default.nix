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
  paperlessUsers = {
    "paperless-admin" = {
      fullName = "Paperless Administrator";
      groups = [];
      isStaff = true;
      isSuperuser = true;
    };

    hannes = {
      fullName = "Hannes";
      groups = ["familie"];
      isStaff = false;
      isSuperuser = false;
    };

    antonia = {
      fullName = "Antonia";
      groups = ["familie"];
      isStaff = false;
      isSuperuser = false;
    };

    luise = {
      fullName = "Luise";
      groups = ["familie"];
      isStaff = false;
      isSuperuser = false;
    };

    dietmar = {
      fullName = "Dietmar";
      groups = ["familie"];
      isStaff = false;
      isSuperuser = false;
    };
  };
  userSecretName = username: "paperless/users/${username}/password";
  provisionedAccounts =
    lib.mapAttrsToList (username: account: {
      inherit username;
      inherit (account) fullName groups isStaff isSuperuser;
      passwordFile = config.sops.secrets.${userSecretName username}.path;
    })
    paperlessUsers;
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

    sops.secrets =
      {
        "paperless/sftp/password_hash" = {
          sopsFile = ../../secrets/infrastructure.yaml;
          owner = "root";
          group = "root";
          mode = "0400";
          neededForUsers = true;
        };
      }
      // lib.mapAttrs' (username: _: {
        name = userSecretName username;
        value = {
          sopsFile = ../../secrets/infrastructure.yaml;
          owner = "paperless";
          group = "paperless";
          mode = "0400";
          restartUnits = ["paperless-provision-accounts.service"];
        };
      })
      paperlessUsers;

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

    systemd = {
      services.paperless-provision-accounts = {
        description = "Provision declarative Paperless users and groups";
        after = ["paperless-scheduler.service"];
        requires = ["paperless-scheduler.service"];
        wantedBy = ["multi-user.target"];

        path = [config.services.paperless.manage];

        serviceConfig = {
          Type = "oneshot";
          User = "paperless";
          Group = "paperless";
          RemainAfterExit = true;
        };

        script = ''
          paperless-manage shell <<'PY'
          import json
          from pathlib import Path

          from django.contrib.auth import get_user_model
          from django.contrib.auth.models import Group

          accounts = json.loads(r'''${builtins.toJSON provisionedAccounts}''')
          User = get_user_model()

          group_names = sorted({
              group_name
              for account in accounts
              for group_name in account["groups"]
          })
          groups = {
              group_name: Group.objects.get_or_create(name=group_name)[0]
              for group_name in group_names
          }

          for account in accounts:
              password = Path(account["passwordFile"]).read_text().strip()
              if not password:
                  raise RuntimeError(
                      f'Password secret for {account["username"]} is empty'
                  )

              user, _ = User.objects.get_or_create(username=account["username"])
              user.first_name = account["fullName"]
              user.last_name = ""
              user.email = ""
              user.is_active = True
              user.is_staff = account["isStaff"]
              user.is_superuser = account["isSuperuser"]
              user.set_password(password)
              user.save()
              user.groups.set([groups[name] for name in account["groups"]])
          PY
        '';
      };

      tmpfiles.rules =
        [
          "d /var/lib/paperless-sftp 0755 root root -"
          "z ${consumptionDir} 2770 paperless paperless -"
        ]
        ++ map (directory: "d ${consumptionDir}/${directory} 2770 paperless paperless -") scannerDirectories;
    };

    networking.firewall.allowedTCPPorts = [80 443];
  };
}
