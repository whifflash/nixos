{
  config,
  lib,
  ...
}: let
  id = "remote_admin_ssh";
  cfg = config.${id};
  sshPortSet = lib.concatStringsSep ", " (map toString config.services.openssh.ports);
in {
  options.${id} = {
    enable = lib.mkEnableOption "key-only remote administration over SSH";

    user = lib.mkOption {
      type = lib.types.str;
      default = "mhr";
      description = "Local user that receives the administrator SSH keys.";
    };

    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILf46c7nmSRrmr/6iZ0ozwxSaGyQa9YJjmCXyu3+w/HN mhr@mia"
      ];
      description = "Public keys permitted to log in as the administrator user.";
    };

    allowLanAccess = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow SSH through the firewall from IPv4 source addresses in 10.0.0.0/8.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.users.users.${cfg.user}.isNormalUser;
        message = "remote_admin_ssh.user must name an existing normal user";
      }
      {
        assertion = !cfg.allowLanAccess || config.networking.firewall.enable;
        message = "remote_admin_ssh.allowLanAccess requires the NixOS firewall to be enabled";
      }
      {
        assertion = !cfg.allowLanAccess || config.networking.firewall.backend == "nftables";
        message = "remote_admin_ssh.allowLanAccess requires the nftables firewall backend";
      }
    ];

    users.users.${cfg.user}.openssh.authorizedKeys.keys = cfg.authorizedKeys;

    services.openssh = {
      enable = true;
      openFirewall = false;

      settings = {
        KbdInteractiveAuthentication = false;
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };

    networking = lib.mkIf cfg.allowLanAccess {
      nftables.enable = true;
      firewall.extraInputRules = ''
        ip saddr 10.0.0.0/8 tcp dport { ${sshPortSet} } accept comment "allow remote administration SSH from LAN"
      '';
    };
  };
}
