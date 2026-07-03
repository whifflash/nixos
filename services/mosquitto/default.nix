{
  config,
  lib,
  ...
}: let
  cfg = config.infra.services.mosquitto;
  primaryPasswordSecret = "mosquitto/users/${cfg.username}/password_hash";
  allUsers =
    {
      ${cfg.username} = {
        passwordSecret = primaryPasswordSecret;
        acl = ["readwrite #"];
      };
    }
    // cfg.additionalUsers;
  userSecrets = lib.mapAttrs' (_username: user:
    lib.nameValuePair user.passwordSecret {
      sopsFile = ../../secrets/infrastructure.yaml;
      key = user.passwordSecret;
      format = "yaml";
      mode = "0400";
    })
  allUsers;
  listenerUsers =
    lib.mapAttrs (_username: user: {
      hashedPasswordFile = config.sops.secrets.${user.passwordSecret}.path;
      inherit (user) acl;
    })
    allUsers;
in {
  options.infra.services.mosquitto = {
    enable = lib.mkEnableOption "the shared Mosquitto MQTT broker";

    username = lib.mkOption {
      type = lib.types.str;
      default = "mosquitto";
      description = "Primary MQTT username provisioned for Home Assistant and LAN clients.";
    };

    additionalUsers = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          passwordSecret = lib.mkOption {
            type = lib.types.str;
            description = "SOPS key containing the Mosquitto password hash for this user.";
          };

          acl = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Mosquitto ACL entries assigned to this user.";
          };
        };
      });
      default = {};
      description = "Additional declaratively provisioned MQTT users.";
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
    sops.secrets = userSecrets;

    services.mosquitto = {
      enable = true;
      persistence = true;
      listeners = [
        {
          inherit (cfg) port;
          address = cfg.listenAddress;
          users = listenerUsers;
        }
      ];
    };

    networking.firewall.allowedTCPPorts = [cfg.port];
  };
}
