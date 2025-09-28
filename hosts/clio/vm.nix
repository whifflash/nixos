{
  lib,
  modulesPath,
  ...
}: {
  virtualisation = {
    # Provide a VM variant that brings in the qemu-vm machinery
    vmVariant = {
      imports = [(modulesPath + "/virtualisation/qemu-vm.nix")];

      # Tell our modules “this is the VM”
      clio.isVM = true;

      # And ensure Disko is OFF in the VM even if enabled by default for host
      clio.enableDisko = lib.mkForce false;

      # The run-*-vm script boots kernel/initrd directly; don’t try to install a bootloader
      boot.loader = {
        systemd-boot.enable = lib.mkForce false;
        efi.canTouchEfiVariables = lib.mkForce false;
        grub.enable = lib.mkForce false;
      };

      virtualisation = {
        # ✅ Let the VM supply its own tmpfs/overlay root filesystem
        useDefaultFilesystems = true;

        cores = 2;
        diskSize = 40960;
        memorySize = 4096;
        graphics = false; # headless

        sharedDirectories.repo = {
          source = "/home/mhr/nixos"; # path on host (mia)
          target = "/mnt/host/nixos"; # mount point *inside* the VM
          # writable = true;         # enable if you want to edit from the VM
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
