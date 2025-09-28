# hosts/clio/storage.nix
{
  config,
  lib,
  inputs,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.clio;
in {
  # Only import disko + define disks on the real machine
  config = mkIf (cfg.enableDisko && !cfg.isVM) {
    imports = [inputs.disko.nixosModules.disko];

    # (No disko.enableConfig here; we’re only declaring desired layout)
    disko.devices = {
      disk.main = {
        # ⚠️ set to your real device on bare metal later (e.g. /dev/nvme0n1)
        device = "/dev/vda";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
              type = "ef00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}
