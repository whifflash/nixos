{
  config,
  lib,
  ...
}: let
  cfg = config.infra.services.mosquitto;
  passwordSecret = "mosquitto/users/${cfg.username}/password_hash";
in {
  options.infra.services.mosquitto = {
    enable = lib.mkEnableOption "the shared Mosquitto MQTT broker";

    username = lib.mkOption {
      type = lib.types.str;
      default = "mosquitto";
      description = "MQTT username provisioned for Home Assistant and LAN clients.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 1883;
      description = "TCP port exposed by the MQTT broker.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "Address on which Mosquitto listens.";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets.${passwordSecret} = {
      sopsFile = ../../secrets/infrastructure.yaml;
      key = passwordSecret;
      format = "yaml";
      mode = "0400";
    };

    services.mosquitto = {
      enable = true;
      persistence = true;
      listeners = [
        {
          inherit (cfg) port;
          address = cfg.listenAddress;
          users.${cfg.username} = {
            hashedPasswordFile = config.sops.secrets.${passwordSecret}.path;
            acl = ["readwrite #"];
          };
        }
      ];
    };

    networking.firewall.allowedTCPPorts = [cfg.port];
  };
}
