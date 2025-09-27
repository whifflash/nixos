{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (config.clio) domain;
in {
  options.clio.domain = lib.mkOption {
    type = lib.types.str;
    description = "Primary domain for Clio (provided by hosts/clio/domain.nix).";
  };

  imports = [
    ./services/hub.nix
    # ./services/gitea.nix
    # ./services/grafana.nix
    # ./services/home-assistant.nix
    # ./services/influxdb2.nix
    # ./services/mosquitto.nix
    # ./services/attic.nix
    # ./services/unifi.nix
  ];

  config = {
    fileSystems."/" = {
      device = "none";
      fsType = "tmpfs";
    };
    boot.loader = {
      grub.enable = false;
      systemd-boot.enable = false;
      efi.canTouchEfiVariables = false;
    };

    time.timeZone = "Europe/Berlin";
    networking = {
      hostName = "clio";
      useDHCP = true;
      firewall = {
        enable = true;
        allowedTCPPorts = [
          22 # ssh
          80 # nginx
          443 #nginz
          1883 # mqtt
          6789 # unify speed test
          8080 # unify device mgmt
        ];
        allowedUDPPorts = [
          3478 # unifi stun
          10001 # unifi ap discovery
        ];
      };
    };

    users = {
      users.mhr = {
        isNormalUser = true;
        extraGroups = ["wheel"];
        openssh.authorizedKeys.keys = [];
        # openssh.authorizedKeys.keys = ["ssh-ed25519 AAAA...replace-with-your-key..."];
      };

      groups.acme = {}; # ensure the group exists
    };

    services.openssh = {
      enable = true;
      settings.PasswordAuthentication = true;
    };

    security = {
      sudo.wheelNeedsPassword = false;

      # ACME via Cloudflare (DNS-01). One wildcard cert reused by vhosts.

      acme = {
        acceptTerms = true;
        defaults = {
          email = "mhr@c4rb0n.cloud";
          dnsProvider = "cloudflare";
          environmentFile = config.sops.secrets."cloudflare/env".path;
          group = "acme";
        };
        certs."wildcard" = {
          domain = "*.${config.clio.domain}";
          extraDomainNames = [config.clio.domain];
          # server = "https://acme-staging-v02.api.letsencrypt.org/directory"; # while testing
        };
      };
    };
  };
}
