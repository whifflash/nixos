{ ... }:
{
  disko.devices = {
    disk.main = {
      device = "/dev/vda";    # QEMU presents the VM disk as /dev/vda
      type = "disk";
      size = "20G";           # VM disk size
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
