{
  inputs,
  lib,
  ...
}: {
  imports = [
    inputs.sops-nix.nixosModules.sops
    ./acme.nix
    ./gitea
    ./home-assistant
    ./home-automation-backup
    ./hub
    ./influxdb
    ./inverter-data-collector
    ./mosquitto
    ./paperless
    ./unifi
  ];

  options.infra.domain = lib.mkOption {
    type = lib.types.str;
    default = "c4rb0n.cloud";
    description = "Base DNS domain used by self-hosted infrastructure services.";
  };
}
