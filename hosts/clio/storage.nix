# hosts/clio/storage.nix
{
  config,
  lib,
  ...
}: let
  cfg = config.clio;
in {
  # Do NOT set imports here; disko is imported in default.nix

  # Only declare disks when enabled and not the VM
  config = lib.mkIf (cfg.enableDisko && !cfg.isVM) {
    disko.devices = {
      disk.main = {
        # TODO: on bare metal, change to your real disk (e.g., /dev/nvme0n1)
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
