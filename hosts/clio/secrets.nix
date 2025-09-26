{
  config,
  lib,
  ...
}: {
  # All clio secrets live here
  sops = {
    defaultSopsFile = ../../secrets/clio.yaml;

    # Cloudflare token for ACME (dotenv with CF_DNS_API_TOKEN=...)
    secrets."cloudflare/env" = {
      key = "cloudflare.env";
      format = "dotenv";
      owner = "root";
      group = "root";
      mode = "0400";
    };

    validateSopsFiles = true;

    age.keyFile = "/etc/sops/age/key.txt";
  };
}
