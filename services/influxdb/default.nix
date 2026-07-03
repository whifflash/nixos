{
  config,
  lib,
  ...
}: let
  cfg = config.infra.services.influxdb;
  hostName =
    if cfg.hostName != null
    then cfg.hostName
    else "influx.${config.infra.domain}";
  adminPasswordSecret = "influxdb/admin_password";
  operatorTokenSecret = "influxdb/operator_token";
  homeAssistantTokenSecret = "influxdb/home_assistant_token";
in {
  options.infra.services.influxdb = {
    enable = lib.mkEnableOption "the shared InfluxDB 2 service";

    hostName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "influx.example.com";
      description = "DNS name for InfluxDB. Defaults to influx.<infra.domain>.";
    };

    httpPort = lib.mkOption {
      type = lib.types.port;
      default = 8086;
      description = "Loopback HTTP port used by Home Assistant and Nginx.";
    };

    organization = lib.mkOption {
      type = lib.types.str;
      default = "bsw";
      description = "Initial InfluxDB organization.";
    };

    bucket = lib.mkOption {
      type = lib.types.str;
      default = "homeassistant";
      description = "InfluxDB bucket receiving Home Assistant measurements.";
    };

    adminUsername = lib.mkOption {
      type = lib.types.str;
      default = "admin";
      description = "Initial InfluxDB administrator username.";
    };

    retentionSeconds = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 0;
      description = "Bucket retention in seconds; zero keeps data indefinitely.";
    };
  };

  config = lib.mkIf cfg.enable {
    infra.acme.enable = true;

    sops.secrets = {
      "influxdb/admin_password" = {
        sopsFile = ../../secrets/infrastructure.yaml;
        owner = "influxdb2";
        group = "influxdb2";
        mode = "0400";
      };

      "influxdb/operator_token" = {
        sopsFile = ../../secrets/infrastructure.yaml;
        owner = "influxdb2";
        group = "influxdb2";
        mode = "0400";
      };

      "influxdb/home_assistant_token" = {
        sopsFile = ../../secrets/infrastructure.yaml;
        owner = "influxdb2";
        group = "influxdb2";
        mode = "0400";
      };
    };

    security.acme.certs.${hostName} = {};

    services = {
      influxdb2 = {
        enable = true;
        settings = {
          "http-bind-address" = "127.0.0.1:${toString cfg.httpPort}";
          "reporting-disabled" = true;
        };

        provision = {
          enable = true;
          initialSetup = {
            inherit (cfg) organization bucket;
            username = cfg.adminUsername;
            retention = cfg.retentionSeconds;
            passwordFile = config.sops.secrets.${adminPasswordSecret}.path;
            tokenFile = config.sops.secrets.${operatorTokenSecret}.path;
          };

          organizations.${cfg.organization}.auths."home-assistant" = {
            description = "Home Assistant bucket writer";
            tokenFile = config.sops.secrets.${homeAssistantTokenSecret}.path;
            writeBuckets = [cfg.bucket];
          };
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
            client_max_body_size 0;
          '';
          locations."/" = {
            proxyPass = "http://127.0.0.1:${toString cfg.httpPort}";
            proxyWebsockets = true;
          };
        };
      };
    };

    networking.firewall.allowedTCPPorts = [80 443];
  };
}
