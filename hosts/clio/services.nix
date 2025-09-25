{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (config.clio.domain) domain;
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
        allowedTCPPorts = [22 80 443];
      };
    };

    users.users.mhr = {
      isNormalUser = true;
      extraGroups = ["wheel"];
      openssh.authorizedKeys.keys = ["ssh-ed25519 AAAA...replace-with-your-key..."];
    };
    services.openssh.enable = true;

    security = {
      sudo.wheelNeedsPassword = false;

      # ACME via Cloudflare (DNS-01). One wildcard cert reused by vhosts.

      acme = {
        acceptTerms = true;
        defaults = {
          email = "mail@EXAMPLE.invalid";
          dnsProvider = "cloudflare";
          environmentFile = config.sops.secrets."cloudflare/env".path;
          group = "nginx";
        };
        certs."wildcard" = {
          domain = "*.${domain}";
          extraDomainNames = [domain];
          # server = "https://acme-staging-v02.api.letsencrypt.org/directory";
        };
      };
    };
  };
}
