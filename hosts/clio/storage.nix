# hosts/clio/storage.nix
{
  lib,
  inputs,
  ...
}: {
  # Disko module for the real machine
  imports = [inputs.disko.nixosModules.disko];

  # Adjust this to the *real* disk when you migrate (e.g., /dev/nvme0n1)
  disko.devices = {
    disk.main = {
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
}
