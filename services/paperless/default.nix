{
  config,
  lib,
  pkgs,
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
  paperlessMetadata = {
    documentTypes = [
      "Bescheid"
      "Bestätigung"
      "Kontoauszug"
      "Mahnung"
      "Nachweis"
      "Police"
      "Rechnung"
      "Schreiben"
      "Vertrag"
      "Einladung"
      "Zugangsdaten"
      "Sonstiges Schreiben"
    ];

    tags = [
      {
        name = "Person";
        parent = null;
        color = "#1f78b4";
      }
      {
        name = "Hannes";
        parent = "Person";
        color = "#a6cee3";
      }
      {
        name = "Antonia";
        parent = "Person";
        color = "#a6cee3";
      }
      {
        name = "Luise";
        parent = "Person";
        color = "#a6cee3";
      }
      {
        name = "Dietmar";
        parent = "Person";
        color = "#a6cee3";
      }
      {
        name = "Bereich";
        parent = null;
        color = "#33a02c";
      }
      {
        name = "Arbeit";
        parent = "Bereich";
        color = "#b2df8a";
      }
      {
        name = "Auto";
        parent = "Bereich";
        color = "#b2df8a";
      }
      {
        name = "Bank";
        parent = "Bereich";
        color = "#b2df8a";
      }
      {
        name = "Gesundheit";
        parent = "Bereich";
        color = "#b2df8a";
      }
      {
        name = "Haus";
        parent = "Bereich";
        color = "#b2df8a";
      }
      {
        name = "Schule";
        parent = "Bereich";
        color = "#b2df8a";
      }
      {
        name = "Finanzen";
        parent = "Bereich";
        color = "#b2df8a";
      }
      {
        name = "Steuer";
        parent = "Finanzen";
        color = "#b2df8a";
      }
      {
        name = "Versicherung";
        parent = "Bereich";
        color = "#b2df8a";
      }
      {
        name = "Status";
        parent = null;
        color = "#ff7f00";
      }
      {
        name = "Eingang";
        parent = "Status";
        color = "#fdbf6f";
        isInboxTag = true;
      }
      {
        name = "Prüfen";
        parent = "Status";
        color = "#fdbf6f";
      }
      {
        name = "Bezahlen";
        parent = "Status";
        color = "#fdbf6f";
      }
      {
        name = "Offen";
        parent = "Status";
        color = "#fdbf6f";
      }
      {
        name = "Erledigt";
        parent = "Status";
        color = "#fdbf6f";
      }
    ];

    storagePaths = {
      Hannes = "hannes/{{ created_year }}/{{ correspondent }}/{{ title }}";
      Antonia = "antonia/{{ created_year }}/{{ correspondent }}/{{ title }}";
      Luise = "luise/{{ created_year }}/{{ correspondent }}/{{ title }}";
      Dietmar = "dietmar/{{ created_year }}/{{ correspondent }}/{{ title }}";
      Familie = "familie/{{ created_year }}/{{ document_type }}/{{ correspondent }}/{{ title }}";
      Eingang = "eingang/{{ added_year }}/{{ added_month }}/{{ original_name }}";
    };
  };
  paperlessGroups = {
    familie.permissions = [
      "add_correspondent"
      "change_correspondent"
      "view_correspondent"
      "add_customfield"
      "change_customfield"
      "view_customfield"
      "add_document"
      "change_document"
      "view_document"
      "add_documenttype"
      "change_documenttype"
      "view_documenttype"
      "add_note"
      "change_note"
      "view_note"
      "change_paperlesstask"
      "view_paperlesstask"
      "add_savedview"
      "change_savedview"
      "view_savedview"
      "add_storagepath"
      "change_storagepath"
      "view_storagepath"
      "add_tag"
      "change_tag"
      "view_tag"
      "add_uisettings"
      "change_uisettings"
      "view_uisettings"
      "view_user"
    ];
  };
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
  provisionedAccountsFile =
    builtins.toFile
    "paperless-provisioned-accounts.json"
    (builtins.toJSON provisionedAccounts);
  provisionedGroupsFile =
    builtins.toFile
    "paperless-provisioned-groups.json"
    (builtins.toJSON paperlessGroups);
  provisionedMetadataFile =
    builtins.toFile
    "paperless-provisioned-metadata.json"
    (builtins.toJSON paperlessMetadata);
  sftpSshdConfig = pkgs.writeText "paperless-sftp-sshd-config" ''
    Port ${toString cfg.sftpPort}
    AddressFamily any
    ListenAddress 0.0.0.0
    ListenAddress ::

    HostKey /etc/ssh/ssh_host_ed25519_key
    HostKey /etc/ssh/ssh_host_rsa_key
    PidFile /run/paperless-sftp-sshd.pid

    UsePAM yes
    PAMServiceName paperless-sftp
    PasswordAuthentication yes
    KbdInteractiveAuthentication no
    PubkeyAuthentication no
    AuthenticationMethods password
    PermitEmptyPasswords no
    PermitRootLogin no
    AllowUsers ${cfg.sftpUser}
    AuthorizedKeysFile none

    AllowAgentForwarding no
    AllowTcpForwarding no
    PermitTunnel no
    PermitTTY no
    X11Forwarding no

    ChrootDirectory /var/lib/paperless-sftp
    ForceCommand internal-sftp -d /upload -u 0007
    Subsystem sftp internal-sftp
    LogLevel VERBOSE
  '';
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

    sftpPort = lib.mkOption {
      type = lib.types.port;
      default = 2223;
      description = "Dedicated TCP port for the scanner-only SFTP daemon.";
    };
  };

  config = lib.mkIf cfg.enable {
    infra.acme.enable = true;

    security = {
      acme.certs.${hostName} = {};
      pam.services.paperless-sftp.unixAuth = true;
    };

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
      services = {
        paperless-sftp-sshd = {
          description = "Dedicated Paperless scanner SFTP daemon";
          after = ["network.target" "sshd.service"];
          wantedBy = ["multi-user.target"];

          serviceConfig = {
            Type = "simple";
            ExecStartPre = "${pkgs.openssh}/bin/sshd -t -f ${sftpSshdConfig}";
            ExecStart = "${pkgs.openssh}/bin/sshd -D -e -f ${sftpSshdConfig}";
            Restart = "on-failure";
            RestartSec = "5s";
          };
        };

        paperless-provision-accounts = {
          description = "Provision declarative Paperless accounts and metadata";
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
            from django.contrib.auth.models import Group, Permission

            from documents.models import DocumentType, StoragePath, Tag

            accounts = json.loads(Path("${provisionedAccountsFile}").read_text())
            declared_groups = json.loads(
                Path("${provisionedGroupsFile}").read_text()
            )
            metadata = json.loads(Path("${provisionedMetadataFile}").read_text())
            User = get_user_model()

            referenced_group_names = {
                group_name
                for account in accounts
                for group_name in account["groups"]
            }
            group_names = sorted(referenced_group_names | declared_groups.keys())
            groups = {
                group_name: Group.objects.get_or_create(name=group_name)[0]
                for group_name in group_names
            }

            for group_name, group_config in declared_groups.items():
                permission_codenames = set(group_config["permissions"])
                permissions = list(
                    Permission.objects.filter(codename__in=permission_codenames)
                )
                resolved_codenames = {
                    permission.codename
                    for permission in permissions
                }
                missing_codenames = sorted(
                    permission_codenames - resolved_codenames
                )
                if missing_codenames:
                    raise RuntimeError(
                        f"Unknown permissions for group {group_name}: "
                        f"{', '.join(missing_codenames)}"
                    )

                groups[group_name].permissions.set(permissions)

            for document_type_name in metadata["documentTypes"]:
                document_type, _ = DocumentType.objects.get_or_create(
                    name=document_type_name,
                    owner=None,
                )
                document_type.match = ""
                document_type.matching_algorithm = DocumentType.MATCH_NONE
                document_type.is_insensitive = True
                document_type.save()

            tags = {}
            pending_tags = list(metadata["tags"])
            while pending_tags:
                created_in_pass = False
                for tag_config in pending_tags.copy():
                    parent_name = tag_config["parent"]
                    if parent_name is not None and parent_name not in tags:
                        continue

                    tag, _ = Tag.objects.get_or_create(
                        name=tag_config["name"],
                        owner=None,
                    )
                    tag.color = tag_config["color"]
                    tag.match = ""
                    tag.matching_algorithm = Tag.MATCH_NONE
                    tag.is_insensitive = True
                    tag.is_inbox_tag = tag_config.get("isInboxTag", False)
                    tag.tn_parent = tags.get(parent_name)
                    tag.full_clean()
                    tag.save()
                    tags[tag_config["name"]] = tag
                    pending_tags.remove(tag_config)
                    created_in_pass = True

                if not created_in_pass:
                    unresolved = sorted(tag["name"] for tag in pending_tags)
                    raise RuntimeError(
                        "Unresolved or cyclic Paperless tag parents: "
                        + ", ".join(unresolved)
                    )

            for storage_path_name, path in metadata["storagePaths"].items():
                storage_path, _ = StoragePath.objects.get_or_create(
                    name=storage_path_name,
                    owner=None,
                )
                storage_path.path = path
                storage_path.match = ""
                storage_path.matching_algorithm = StoragePath.MATCH_NONE
                storage_path.is_insensitive = True
                storage_path.full_clean()
                storage_path.save()

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
      };

      tmpfiles.rules =
        [
          "d /run/sshd 0755 root root -"
          "d /var/lib/paperless-sftp 0755 root root -"
          "z ${consumptionDir} 2770 paperless paperless -"
        ]
        ++ map (directory: "d ${consumptionDir}/${directory} 2770 paperless paperless -") scannerDirectories;
    };

    networking.firewall.allowedTCPPorts = [
      80
      443
      cfg.sftpPort
    ];
  };
}
