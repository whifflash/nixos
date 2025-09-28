# hosts/clio/storage.nix
{
  config,
  lib,
  inputs,
  ...
}: let
  inherit (lib) mkIf mkEnableOption optional;
  cfg = config.clio;
  enableDiskoHere = cfg.enableDisko && !cfg.isVM;
in {
  # toggle lives in hosts/clio/options.nix
  # options.clio.enableDisko is defined there

  # 1) imports must be top-level; make it conditional with lib.optional
  imports = optional enableDiskoHere inputs.disko.nixosModules.disko;

  # 2) the rest of the config can be gated with mkIf
  config = mkIf enableDiskoHere {
    disko.devices = {
      disk.main = {
        # NOTE: set to your real device on bare metal later (e.g. /dev/nvme0n1)
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
