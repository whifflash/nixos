{
  config,
  lib,
  ...
}:
let
  id = "remote_admin_ssh";
  cfg = config.${id};
  firewallEnabled = config.networking.firewall.enable;
  nftablesFirewall = firewallEnabled && config.networking.firewall.backend == "nftables";
  sshPortSet = lib.concatStringsSep ", " (map toString config.services.openssh.ports);
in
{
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
      description = "Allow SSH connections only from IPv4 source addresses in 10.0.0.0/8.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = config.users.users.${cfg.user}.isNormalUser;
            message = "remote_admin_ssh.user must name an existing normal user";
          }
        ];

        users.users.${cfg.user}.openssh.authorizedKeys.keys = cfg.authorizedKeys;

        services.openssh = {
          enable = true;

          # With the nftables firewall, the source range is filtered below. For
          # other enabled firewall backends, open the configured SSH ports and
          # let sshd enforce the same source restriction. A disabled firewall is
          # left disabled, which is intentional for workstation hosts such as
          # luna.
          openFirewall = cfg.allowLanAccess && firewallEnabled && !nftablesFirewall;

          settings = {
            KbdInteractiveAuthentication = false;
            PasswordAuthentication = false;
            PermitRootLogin = "no";
          };

          # Keep this at the end of sshd_config so no later module setting is
          # accidentally scoped inside the Match block. OpenSSH 9.9 and newer
          # support RefuseConnection in Match blocks.
          extraConfig = lib.mkAfter (
            lib.optionalString cfg.allowLanAccess ''
              Match Address *,!10.0.0.0/8
                RefuseConnection yes
            ''
          );
        };
      }

      # Preserve source filtering at the packet layer on hosts that already use
      # the NixOS nftables firewall. This does not enable or change the global
      # firewall state on luna or any other host.
      (lib.mkIf (cfg.allowLanAccess && nftablesFirewall) {
        networking.firewall.extraInputRules = ''
          ip saddr 10.0.0.0/8 tcp dport { ${sshPortSet} } accept comment "allow remote administration SSH from LAN"
        '';
      })
    ]
  );
}
