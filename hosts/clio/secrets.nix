{ inputs, config, lib, pkgs, ... }:
{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  sops = {
    # Encrypted file that contains `cloudflare.env` (YAML)
    defaultSopsFile = ../../secrets/clio.yaml;

    # Decryption key available at activation time
    age.keyFile = "/var/lib/sops-nix/key.txt";

    # Helpful during builds; will fail early if the YAML/keys are wrong
    validateSopsFiles = true;

    # Write /run/secrets/cloudflare/env from YAML key cloudflare.env
    secrets."cloudflare/env" = {
      format = "yaml";
      key    = "cloudflare.env";  # NOTE: case must match the YAML exactly
      owner  = "root";
      group  = "root";
      mode   = "0400";
    };
  };
}
