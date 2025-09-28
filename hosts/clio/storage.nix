{ lib, ... }:
let
  inherit (lib) mkIf mkEnableOption;
in
{
  options.clio.enableDisko = mkEnableOption "Enable Disko-managed disks for Clio";

  config = mkIf config.clio.enableDisko {
    # NOTE: disko module is already imported via default.nix
    # Define your disk layout here. (singular 'disk' is correct)
    disko.devices = {
      disk.main = {
        device = "/dev/vda";   # change to your real disk on bare metal
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
