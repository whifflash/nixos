# hosts/clio-vm/vm.nix
{
  lib,
  modulesPath,
  ...
}: {
  virtualisation.vmVariant = {
    # Bring in the qemu-vm machinery for the VM variant
    imports = [(modulesPath + "/virtualisation/qemu-vm.nix")];

    # ---- QEMU resources ----
    virtualisation = {
      memorySize = 4096; # 4 GiB
      cores = 2;
      diskSize = 40960; # 40 GiB qcow2
      graphics = false; # headless
      useDefaultFilesystems = true; # tmpfs/overlay root
      sharedDirectories.repo = {
        source = "/home/mhr/nixos"; # on HOST
        target = "/mnt/host/nixos"; # inside VM
        # writable = true;
      };
    };

    # Share your repo into the guest

    # ---- Port forwards (host -> guest) ----
    # Be explicit about addresses so qemu emits hostfwd entries.
    virtualisation.forwardPorts = [
      # SSH
      {
        from = "host";
        host = {
          address = "0.0.0.0";
          port = 3333;
        };
        guest = {
          address = "10.0.2.15";
          port = 22;
        };
      }

      # HTTP/S
      {
        from = "host";
        host = {
          address = "0.0.0.0";
          port = 8880;
        };
        guest = {
          address = "10.0.2.15";
          port = 80;
        };
      }
      {
        from = "host";
        host = {
          address = "0.0.0.0";
          port = 8443;
        };
        guest = {
          address = "10.0.2.15";
          port = 443;
        };
      }

      # TCP services
      {
        from = "host";
        host = {
          address = "0.0.0.0";
          port = 1883;
        };
        guest = {
          address = "10.0.2.15";
          port = 1883;
        };
      }
      {
        from = "host";
        host = {
          address = "0.0.0.0";
          port = 6789;
        };
        guest = {
          address = "10.0.2.15";
          port = 6789;
        };
      }
      {
        from = "host";
        host = {
          address = "0.0.0.0";
          port = 8080;
        };
        guest = {
          address = "10.0.2.15";
          port = 8080;
        };
      }

      # UDP (SLIRP supports these too)
      {
        from = "host";
        host = {
          address = "0.0.0.0";
          port = 3478;
        };
        guest = {
          address = "10.0.2.15";
          port = 3478;
        };
        proto = "udp";
      }
      {
        from = "host";
        host = {
          address = "0.0.0.0";
          port = 10001;
        };
        guest = {
          address = "10.0.2.15";
          port = 10001;
        };
        proto = "udp";
      }
    ];

    # Don’t try to install a bootloader inside run-*-vm
    boot.loader = {
      systemd-boot.enable = lib.mkForce false;
      efi.canTouchEfiVariables = lib.mkForce false;
      grub.enable = lib.mkForce false;
    };

    # Make sure there is something to reach in the guest
    services.openssh.enable = true;
    networking.firewall = {
      allowedTCPPorts = [22 80 443 1883 6789 8080];
      allowedUDPPorts = [3478 10001];
    };
  };
}
