{
  lib,
  modulesPath,
  ...
}: {
  virtualisation = {
    # Provide a VM variant that brings in the qemu-vm machinery
    vmVariant = {
      imports = [(modulesPath + "/virtualisation/qemu-vm.nix")];

      # Disable bootloader installation in the VM
      boot.loader.systemd-boot.enable = lib.mkForce false;
      boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
      boot.loader.grub.enable = lib.mkForce false;

      # IMPORTANT: provide / and /boot so evaluation knows there is a root fs
      fileSystems."/" = {
        device = "/dev/vda2"; # matches the root partition in your disko (vda2)
        fsType = "ext4";
        neededForBoot = true;
      };
      fileSystems."/boot" = {
        device = "/dev/vda1"; # ESP created by disko (vda1)
        fsType = "vfat";
        neededForBoot = true;
      };

      virtualisation = {
        useDefaultFilesystems = false; # account ing for disko
        cores = 2;
        diskSize = 40960;
        memorySize = 4096;
        # optional:
        graphics = false; # headless

        sharedDirectories.repo = {
          source = "/home/mhr/nixos"; # path on host (mia)
          target = "/mnt/host/nixos"; # mount point *inside* the VM
          # writable = true;            # set if you want to edit from the VM
        };

        forwardPorts = [
          {
            from = "host";
            host.port = 3333;
            guest.port = 22;
          }
          {
            from = "host";
            host.port = 8880;
            guest.port = 80;
          }
          {
            from = "host";
            host.port = 8443;
            guest.port = 443;
          }
          {
            from = "host";
            host.port = 1883;
            guest.port = 1883;
          }
          {
            from = "host";
            host.port = 6789;
            guest.port = 6789;
          }
          {
            from = "host";
            host.port = 8080;
            guest.port = 8080;
          }
          {
            from = "host";
            host.port = 3478;
            guest.port = 3478;
            proto = "udp";
          }
          {
            from = "host";
            host.port = 10001;
            guest.port = 10001;
            proto = "udp";
          }
        ];
      };
    };
  };
}
