{
  config,
  lib,
  ...
}: let
  id = "remote_admin_ssh";
  cfg = config.${id};
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

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open the configured SSH port in the NixOS firewall.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.users.users.${cfg.user}.isNormalUser;
        message = "remote_admin_ssh.user must name an existing normal user";
      }
    ];

    users.users.${cfg.user}.openssh.authorizedKeys.keys = cfg.authorizedKeys;

    services.openssh = {
      enable = true;
      inherit (cfg) openFirewall;

      settings = {
        KbdInteractiveAuthentication = false;
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };
  };
}
