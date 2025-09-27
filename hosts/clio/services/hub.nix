# hosts/clio/services/hub.nix
{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (config.clio) domain;
  hubRoot = "/etc/clio-hub";
in {
  environment.etc."clio-hub".source = ./../assets/hub;

  services.nginx = {
    enable = true;
    recommendedTlsSettings = true;
    recommendedProxySettings = true;

    virtualHosts = {
      # public hub.<domain> -> proxy to local-only backend
      "${"hub." + domain}" = {
        enableACME = false; # use the wildcard cert
        useACMEHost = "wildcard";
        forceSSL = true;
        locations."/".proxyPass = "http://127.0.0.1:8082";
      };

      # catch-all: redirect any unknown subdomain to hub.<domain>
      "_" = {
        enableACME = false;
        useACMEHost = "wildcard";
        forceSSL = true;
        locations."/".return = "302 https://hub-t .${domain}";
      };

      # local-only backend that serves the static hub
      "hub-local" = {
        listen = [
          {
            addr = "127.0.0.1";
            port = 8082;
          }
        ];
        root = hubRoot;
        extraConfig = ''autoindex off; '';
      };
    };
  };
}
