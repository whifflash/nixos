{ config, pkgs, lib, ... }:

let
  domain = lib.strings.trim (builtins.readFile config.sops.secrets."clio/domain_name".path);
in
{
  #### make domain available to all service modules
  options.clio.domain = lib.mkOption {
    type = lib.types.str;
    readOnly = true;
    description = "Primary domain for Clio (from secret).";
  };

  #### import services (only hub for now)
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

  #### host config
  config = {
    clio.domain = domain;

    time.timeZone = "Europe/Berlin";
    networking.hostName = "clio";
    networking.useDHCP = true;

    users.users.mhr = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAA...replace-with-your-key..." ];
    };
    services.openssh.enable = true;
    security.sudo.wheelNeedsPassword = false;

    networking.firewall.enable = true;
    networking.firewall.allowedTCPPorts = [ 22 80 443 ];

    security.acme = {
      acceptTerms = true;
      defaults = {
        email = "mail@EXAMPLE.invalid";
        dnsProvider = "cloudflare";
        environmentFile = config.sops.secrets."cloudflare/env".path;
      };
      certs."wildcard" = {
        domain = "*.${domain}";
        extraDomainNames = [ "${domain}" ];
        # server = "https://acme-staging-v02.api.letsencrypt.org/directory";
      };
    };
  };
}
