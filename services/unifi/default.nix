{
  config,
  lib,
  ...
}: let
  cfg = config.infra.services.unifi;
  hostName =
    if cfg.hostName != null
    then cfg.hostName
    else "unifi.${config.infra.domain}";
in {
  options.infra.services.unifi = {
    enable = lib.mkEnableOption "the shared UniFi Network Application container";

    hostName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "unifi.example.com";
      description = "Public DNS name for UniFi. Defaults to unifi.<infra.domain>.";
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/jacobalberty/unifi:v8.6.9";
      description = "Pinned UniFi Network Application OCI image.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/unifi";
      description = "Persistent UniFi state directory mounted at /unifi.";
    };

    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Start UniFi automatically. Keep false until the application backup has been restored.";
    };

    httpsPort = lib.mkOption {
      type = lib.types.port;
      default = 8443;
      description = "Internal UniFi HTTPS port used by Nginx.";
    };

    informPort = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "UniFi device inform port exposed on the LAN.";
    };

    stunPort = lib.mkOption {
      type = lib.types.port;
      default = 3478;
      description = "UniFi STUN port exposed on the LAN.";
    };

    discoveryPort = lib.mkOption {
      type = lib.types.port;
      default = 10001;
      description = "UniFi layer-3 discovery port exposed on the LAN.";
    };
  };

  config = lib.mkIf cfg.enable {
    infra.acme.enable = true;

    security.acme.certs.${hostName} = {};

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 root root - -"
    ];

    virtualisation.oci-containers = {
      backend = "podman";

      containers.unifi = {
        inherit (cfg) image autoStart;
        pull = "missing";
        volumes = [
          "${cfg.dataDir}:/unifi"
          "/etc/localtime:/etc/localtime:ro"
        ];
        extraOptions = [
          "--network=host"
        ];
      };
    };

    services.nginx = {
      enable = true;
      recommendedGzipSettings = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;

      virtualHosts.${hostName} = {
        useACMEHost = hostName;
        forceSSL = true;

        extraConfig = ''
          client_max_body_size 1G;
        '';

        locations."/" = {
          proxyPass = "https://127.0.0.1:${toString cfg.httpsPort}";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_ssl_verify off;
            proxy_buffering off;
          '';
        };
      };
    };

    networking.firewall = {
      allowedTCPPorts = [
        80
        443
        cfg.informPort
      ];
      allowedUDPPorts = [
        cfg.stunPort
        cfg.discoveryPort
      ];
    };
  };
}
