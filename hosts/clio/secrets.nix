{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [inputs.sops-nix.nixosModules.sops];

  sops = {
    # Encrypted file that contains `cloudflare.env` (YAML)
    defaultSopsFile = ../../secrets/clio.yaml;

    # Decryption key available at activation time
    age.keyFile = "/root/.config/sops/age/keys.txt";

    # Helpful during builds; will fail early if the YAML/keys are wrong
    validateSopsFiles = false;

    # Write /run/secrets/cloudflare/env from YAML key cloudflare.env
    secrets."cloudflare/env" = {
      sopsFile = ../../secrets/clio.yaml;
      # ✅ precise nested path (robust against dots in key names)
      key = "[\"cloudflare\"][\"env\"]";
      # ✅ tell sops-nix to treat it as a dotenv file
      format = "dotenv";
      owner = "root";
      group = "root";
      mode = "0400";
    };
  };
}
