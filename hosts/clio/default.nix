# hosts/clio/default.nix
{
  inputs,
  lib,
  ...
}: {
  imports = [
    ./common.nix
    ./storage.nix
  ];

  networking.hostName = "clio";

  # Real machine bootloader (UEFI, adjust as you like)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "24.05";
}
