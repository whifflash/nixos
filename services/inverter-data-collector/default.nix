{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.infra.services.inverterDataCollector;
  mqttPasswordSecret = "inverter-data-collector/mqtt_password";
  mqttPasswordHashSecret = "mosquitto/users/${cfg.mqtt.username}/password_hash";
  python = pkgs.python3.withPackages (pythonPackages: [
    pythonPackages.paho-mqtt
    pythonPackages.pysunspec2
  ]);
in {
  options.infra.services.inverterDataCollector = {
    enable = lib.mkEnableOption "the SMA inverter data collector";

    inverter = {
      host = lib.mkOption {
        type = lib.types.str;
        default = "10.20.80.101";
        description = "Hostname or IP address of the SMA SunSpec Modbus TCP endpoint.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 502;
        description = "SunSpec Modbus TCP port.";
      };

      slaveId = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 126;
        description = "SunSpec Modbus unit identifier.";
      };
    };

    mqtt = {
      host = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "MQTT broker hostname or IP address.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 1883;
        description = "MQTT broker port.";
      };

      username = lib.mkOption {
        type = lib.types.str;
        default = "inverter-data-collector";
        description = "Dedicated MQTT username provisioned for the collector.";
      };

      stateTopic = lib.mkOption {
        type = lib.types.str;
        default = "house/pv/sma/stp20_50/state";
        description = "MQTT topic receiving inverter JSON state.";
      };

      availabilityTopic = lib.mkOption {
        type = lib.types.str;
        default = "house/pv/sma/stp20_50/availability";
        description = "MQTT availability topic for the collector.";
      };

      discoveryPrefix = lib.mkOption {
        type = lib.types.str;
        default = "homeassistant";
        description = "Home Assistant MQTT discovery prefix.";
      };
    };

    pollInterval = lib.mkOption {
      type = lib.types.ints.positive;
      default = 5;
      description = "Seconds between inverter reads.";
    };

    retryInterval = lib.mkOption {
      type = lib.types.ints.positive;
      default = 15;
      description = "Seconds to wait before reconnecting after an inverter or MQTT failure.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.infra.services.mosquitto.enable;
        message = "infra.services.inverterDataCollector requires infra.services.mosquitto.enable.";
      }
    ];

    infra.services.mosquitto.additionalUsers.${cfg.mqtt.username} = {
      passwordSecret = mqttPasswordHashSecret;
      acl = [
        "write ${cfg.mqtt.stateTopic}"
        "write ${cfg.mqtt.availabilityTopic}"
        "write ${cfg.mqtt.discoveryPrefix}/#"
      ];
    };

    sops.secrets.${mqttPasswordSecret} = {
      sopsFile = ../../secrets/infrastructure.yaml;
      key = mqttPasswordSecret;
      format = "yaml";
      mode = "0400";
    };

    systemd.services.inverter-data-collector = {
      description = "SMA inverter data collector";
      wantedBy = ["multi-user.target"];
      after = [
        "network-online.target"
        "mosquitto.service"
      ];
      wants = ["network-online.target"];
      requires = ["mosquitto.service"];

      environment = {
        SMA_HOST = cfg.inverter.host;
        SMA_MODBUS_PORT = toString cfg.inverter.port;
        SMA_SLAVE_ID = toString cfg.inverter.slaveId;
        POLL_SECONDS = toString cfg.pollInterval;
        RETRY_SECONDS = toString cfg.retryInterval;
        MQTT_HOST = cfg.mqtt.host;
        MQTT_PORT = toString cfg.mqtt.port;
        MQTT_USERNAME = cfg.mqtt.username;
        MQTT_STATE_TOPIC = cfg.mqtt.stateTopic;
        MQTT_AVAIL_TOPIC = cfg.mqtt.availabilityTopic;
        HA_DISCOVERY_PREFIX = cfg.mqtt.discoveryPrefix;
      };

      serviceConfig = {
        Type = "simple";
        ExecStart = "${python}/bin/python -u ${./collector.py}";
        LoadCredential = "mqtt-password:${config.sops.secrets.${mqttPasswordSecret}.path}";
        Restart = "on-failure";
        RestartSec = "10s";

        DynamicUser = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        SystemCallArchitectures = "native";
        UMask = "0077";
      };
    };
  };
}
