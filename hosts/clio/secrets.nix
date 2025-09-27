{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [ inputs.sops-nix.nixosModules.sops ];
  # All clio secrets live here
  sops = {
    defaultSopsFile = ../../secrets/clio.yaml;

  secrets."cloudflare/env" = {
    format = "dotenv";
    # If the consumer is a non-root service, set owner/group to that user.
    owner = "root";
    group = "root";
    mode  = "0400";
    # If a service reads it, add it here to restart on change, e.g.:
    # restartUnits = [ "caddy.service" ];
  };

  age.keyFile = "/var/lib/sops-nix/key.txt";

  validateSopsFiles = true;

  };
}
