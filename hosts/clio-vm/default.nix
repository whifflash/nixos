# hosts/clio-vm/default.nix
{
  inputs,
  lib,
  modulesPath,
  ...
}: {
  imports = [
    # (modulesPath + "/virtualisation/qemu-vm.nix")
    ../clio/common.nix
    ./vm.nix
  ];

  networking.hostName = lib.mkForce "clio-vm";
  /*
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = ["mode=0755"];
  };
  */
  # never try to install a bootloader inside the run-*-vm environment
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
  boot.loader.grub.enable = lib.mkForce false;

  system.stateVersion = "24.05";
}
