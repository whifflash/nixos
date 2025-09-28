{ lib, inputs, config, ... }:
let
  inherit (lib) mkIf mkEnableOption;
in
{
  options.clio.enableDisko = mkEnableOption "Enable Disko-managed disks for Clio";

  config = mkIf config.clio.enableDisko {
    imports = [
      inputs.disko.nixosModules.disko
    ];

    # Your (real hardware) disk layout — adjust as needed
    disko.devices = {
      disk.main = {
        device = "/dev/vda";   # <- set to the *real* device when deploying (e.g. /dev/nvme0n1)
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
