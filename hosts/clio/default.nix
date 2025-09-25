{
  inputs,
  lib,
  pkgs,
  ...
}: {
  imports = [
    # ../mia/hardware-configuration.nix
    inputs.sops-nix.nixosModules.sops
    ./vm.nix
    ./domain.nix
    ./secrets.nix
    ./services.nix
  ];

  networking.hostName = "clio";

  system.stateVersion = "24.05";
}
