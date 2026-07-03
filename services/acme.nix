{
  config,
  lib,
  ...
}: let
  cfg = config.infra.acme;
in {
  options.infra.acme = {
    enable = lib.mkEnableOption "shared ACME configuration for infrastructure services";

    email = lib.mkOption {
      type = lib.types.str;
      default = "mhr@c4rb0n.cloud";
      description = "Contact email used for ACME account registration.";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets."cloudflare/env" = {
      sopsFile = ../secrets/infrastructure.yaml;
      key = "cloudflare/env";
      format = "yaml";
      owner = "root";
      group = "root";
      mode = "0400";
    };

    security.acme = {
      acceptTerms = true;
      defaults = {
        inherit (cfg) email;
        dnsProvider = "cloudflare";
        environmentFile = config.sops.secrets."cloudflare/env".path;
        group = "nginx";
      };
    };
  };
}
