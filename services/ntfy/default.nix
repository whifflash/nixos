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
      passwordHashSecret = lib.mkOption {
        type = lib.types.str;
        default = "ntfy/users/${name}/password_hash";
        description = "SOPS key containing this ntfy user's bcrypt password hash.";
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

  authFile = "/var/lib/ntfy-sh/user.db";
  environmentTemplateName = "ntfy/environment";
  authUsers =
    lib.mapAttrsToList (
      username: user: "${username}:${config.sops.placeholder.${user.passwordHashSecret}}:${user.role}"
    )
    cfg.users;
  authAccess = lib.concatLists (lib.mapAttrsToList (
      username: user:
        map (entry: "${username}:${entry.topic}:${entry.permission}") user.access
    )
    cfg.users);
  authUsersValue = lib.concatStringsSep "," authUsers;
  authAccessValue = lib.concatStringsSep "," authAccess;
  environmentFile = config.sops.templates.${environmentTemplateName}.path;
  topicCatalogEntries = [
    {
      name = cfg.topics.critical;
      severity = "critical";
      description = "Critical infrastructure alerts requiring immediate attention.";
    }
    {
      name = cfg.topics.warning;
      severity = "warning";
      description = "Infrastructure warnings that may require intervention.";
    }
    {
      name = cfg.topics.info;
      severity = "info";
      description = "Informational alerts and low-priority notices.";
    }
  ];
  topicCatalogJson = builtins.toJSON {
    server = "https://${hostName}";
    topics = topicCatalogEntries;
  };
  topicCatalogHtml = ''
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Icarus notification topics</title>
        <style>
          :root { color-scheme: light dark; font-family: system-ui, sans-serif; }
          body { max-width: 48rem; margin: 0 auto; padding: 2rem 1rem; line-height: 1.5; }
          h1 { margin-bottom: .25rem; }
          .subtitle { margin-top: 0; opacity: .75; }
          ul { list-style: none; padding: 0; display: grid; gap: 1rem; }
          li { border: 1px solid color-mix(in srgb, currentColor 25%, transparent); border-radius: .75rem; padding: 1rem; }
          a { font-weight: 700; overflow-wrap: anywhere; }
          code { font-size: .95em; }
          .severity { text-transform: uppercase; font-size: .75rem; letter-spacing: .08em; opacity: .7; }
        </style>
      </head>
      <body>
        <h1>Icarus notification topics</h1>
        <p class="subtitle">Sign in to <code>${lib.escapeXML hostName}</code> before subscribing.</p>
        <ul>
          ${lib.concatMapStringsSep "\n" (topic: ''
        <li>
          <div class="severity">${lib.escapeXML topic.severity}</div>
          <a href="https://${lib.escapeXML hostName}/${lib.escapeXML topic.name}">${lib.escapeXML topic.name}</a>
          <p>${lib.escapeXML topic.description}</p>
        </li>
      '')
      topicCatalogEntries}
        </ul>
        <p><a href="/topics.json">Machine-readable topic catalog</a></p>
      </body>
    </html>
  '';
  topicCatalog = pkgs.symlinkJoin {
    name = "ntfy-topic-catalog";
    paths = [
      (pkgs.writeTextDir "index.html" topicCatalogHtml)
      (pkgs.writeTextDir "topics.json" topicCatalogJson)
    ];
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

    sops = {
      secrets = lib.mapAttrs' (_username: user:
        lib.nameValuePair user.passwordHashSecret {
          sopsFile = ../../secrets/infrastructure.yaml;
          key = user.passwordHashSecret;
          mode = "0400";
        })
      cfg.users;

      templates.${environmentTemplateName} = {
        content = ''
          NTFY_AUTH_USERS='${authUsersValue}'
          NTFY_AUTH_ACCESS='${authAccessValue}'
        '';
        mode = "0400";
      };
    };

    services = {
      ntfy-sh = {
        enable = true;
        inherit environmentFile;
        settings = {
          base-url = "https://${hostName}";
          listen-http = "127.0.0.1:${toString cfg.port}";
          behind-proxy = true;
          auth-file = authFile;
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
          locations = {
            "= /topics".return = "302 /topics/";

            "/topics/" = {
              alias = "${topicCatalog}/";
              index = "index.html";
              extraConfig = ''
                add_header Cache-Control "public, max-age=300" always;
              '';
            };

            "= /topics.json" = {
              alias = "${topicCatalog}/topics.json";
              extraConfig = ''
                default_type application/json;
                add_header Cache-Control "public, max-age=300" always;
              '';
            };

            "/" = {
              proxyPass = "http://127.0.0.1:${toString cfg.port}";
              proxyWebsockets = true;
            };
          };
        };
      };
    };
  };
}
