{
  config,
  lib,
  ...
}: let
  cfg = config.infra.services.hub;
  hostName =
    if cfg.hostName != null
    then cfg.hostName
    else "hub.${config.infra.domain}";
  certificateName = "wildcard-${config.infra.domain}";
  hubRoot = "/etc/infra-hub";
in {
  options.infra.services.hub = {
    enable = lib.mkEnableOption "the infrastructure service hub";

    hostName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "hub.example.com";
      description = "DNS name for the service hub. Defaults to hub.<infra.domain>.";
    };

    backendPort = lib.mkOption {
      type = lib.types.port;
      default = 8082;
      description = "Loopback port used by the static hub backend.";
    };
  };

  config = lib.mkIf cfg.enable {
    infra.acme.enable = true;

    environment.etc."infra-hub".source = ./assets;

    security.acme.certs.${certificateName} = {
      domain = config.infra.domain;
      extraDomainNames = ["*.${config.infra.domain}"];
      group = "nginx";
    };

    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;

      virtualHosts = {
        "${hostName}" = {
          useACMEHost = certificateName;
          forceSSL = true;
          locations."/".proxyPass = "http://127.0.0.1:${toString cfg.backendPort}";
        };

        "_" = {
          useACMEHost = certificateName;
          forceSSL = true;
          locations."/".return = "302 https://${hostName}$request_uri";
        };

        "hub-local" = {
          listen = [
            {
              addr = "127.0.0.1";
              port = cfg.backendPort;
            }
          ];
          root = hubRoot;
          extraConfig = ''
            autoindex off;
          '';
        };
      };
    };

    networking.firewall.allowedTCPPorts = [80 443];
  };
}
