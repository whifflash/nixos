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

    services.gitea = {
      enable = true;
      database.type = "sqlite3";
      lfs.enable = false;

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

    services.nginx = {
      enable = true;
      recommendedGzipSettings = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;

      virtualHosts.${hostName} = {
        enableACME = true;
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

    networking.firewall.allowedTCPPorts = [
      80
      443
      cfg.sshPort
    ];
  };
}
