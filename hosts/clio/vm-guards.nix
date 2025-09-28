# hosts/clio/vm-guards.nix
{
  lib,
  config,
  ...
}: let
  cfg = config.clio;
in {
  config = lib.mkIf cfg.isVM {
    boot.loader.systemd-boot.enable = lib.mkForce false;
    boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
    boot.loader.grub.enable = lib.mkForce false;
    virtualisation.virtualisation.useDefaultFilesystems = lib.mkDefault true;
  };
}
