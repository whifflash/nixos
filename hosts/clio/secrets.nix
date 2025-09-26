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
    owner = "root";
    group = "root";
    mode = "0400";
  };

  age.keyFile = "/home/mhr/.config/sops/age/keys.txt";

  validateSopsFiles = true;

  };
}
