{ inputs, lib, pkgs, ... }:
{
  imports = [
    inputs.sops-nix.nixosModules.sops
    ./domain.nix
    ./secrets.nix
    ./services.nix
  ];

  networking.hostName = "clio";

  system.stateVersion = "24.05";
}
