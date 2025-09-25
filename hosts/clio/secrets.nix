{ config, lib, ... }:
{
  # all clio secrets live here
  sops.defaultSopsFile = ../../secrets/clio.yaml;

  # secret domain (raw single-line file)
  sops.secrets."clio/domain_name" = {
    key = "domain_name";
    format = "raw";
    owner = "root"; group = "root"; mode = "0400";
  };

  # cloudflare token for ACME (dotenv line CF_DNS_API_TOKEN=...)
  sops.secrets."cloudflare/env" = {
    key = "cloudflare.env";
    format = "dotenv";
    owner = "root"; group = "root"; mode = "0400";
  };

  # OPTIONAL: tell sops-nix where to find the age private keys at activation
  # sops.age.keyFile = "/root/.config/sops/age/keys.txt";
}
