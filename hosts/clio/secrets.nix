{
  config,
  lib,
  ...
}: {
  # All clio secrets live here
  sops = {
    defaultSopsFile = ../../secrets/clio.yaml;

  secrets."cloudflare/env" = {
    sopsFile = ../../secrets/clio.yaml;
    # select the nested YAML key precisely:
    key = "[\"cloudflare\"][\"env\"]";
    format = "dotenv";
  };

  # optional: indicate where the age private key lives on the machine
  age.keyFile = "/home/mhr/.config/sops/age/keys.txt";

    validateSopsFiles = true;

    # age.keyFile = "/etc/sops/age/key.txt";
  };
}
