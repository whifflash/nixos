{
  config,
  lib,
  ...
}: let
  cfg = config.infra.services.homeAssistant;
  hostName =
    if cfg.hostName != null
    then cfg.hostName
    else "ha.${config.infra.domain}";
  secretsYamlSecret = "home-assistant/secrets.yaml";
in {
  options.infra.services.homeAssistant = {
    enable = lib.mkEnableOption "the shared Home Assistant container";

    hostName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "ha.example.com";
      description = "DNS name for Home Assistant. Defaults to ha.<infra.domain>.";
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/home-assistant/home-assistant:2026.7.0";
      description = "Pinned Home Assistant OCI image; add a digest after validating the migration.";
    };

    httpPort = lib.mkOption {
      type = lib.types.port;
      default = 8123;
      description = "Home Assistant HTTP port used by Nginx.";
    };

    configDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/home-assistant";
      description = "Persistent Home Assistant configuration directory mounted at /config.";
    };

    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Start Home Assistant automatically. Keep false until state and Zigbee hardware are migrated.";
    };

    zigbeeDevice = lib.mkOption {
      type = lib.types.str;
      default = "/dev/serial/by-id/usb-Silicon_Labs_Sonoff_Zigbee_3.0_USB_Dongle_Plus_0001-if00-port0";
      description = "Stable host path for the Sonoff Zigbee coordinator exposed as /dev/ttyZIGBEE.";
    };
  };

  config = lib.mkIf cfg.enable {
    infra.acme.enable = true;

    sops.secrets.${secretsYamlSecret} = {
      sopsFile = ../../secrets/infrastructure.yaml;
      key = "home_assistant/secrets_yaml";
      format = "yaml";
      mode = "0400";
    };

    security.acme.certs.${hostName} = {};

    systemd = {
      tmpfiles.rules = [
        "d ${cfg.configDir} 0750 root root - -"
      ];

      services."podman-home-assistant" = {
        after = [
          "influxdb2.service"
          "mosquitto.service"
          "network-online.target"
        ];
        wants = [
          "influxdb2.service"
          "mosquitto.service"
          "network-online.target"
        ];
      };
    };

    virtualisation.oci-containers = {
      backend = "podman";
      containers."home-assistant" = {
        inherit (cfg) image autoStart;
        pull = "missing";
        volumes = [
          "${cfg.configDir}:/config"
          "${config.sops.secrets.${secretsYamlSecret}.path}:/config/secrets.yaml:ro"
          "/etc/localtime:/etc/localtime:ro"
        ];
        devices = [
          "${cfg.zigbeeDevice}:/dev/ttyZIGBEE"
        ];
        extraOptions = [
          "--network=host"
          "--cap-add=NET_ADMIN"
          "--cap-add=NET_RAW"
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
          client_max_body_size 512M;
        '';
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString cfg.httpPort}";
          proxyWebsockets = true;
        };
      };
    };

    networking.firewall.allowedTCPPorts = [80 443];
  };
}
