# hosts/clio-vm/vm.nix
{lib, ...}: {
  virtualisation = {
    vmVariant = {
      virtualisation = {
        # let the VM provide its own tmpfs/overlay root
        useDefaultFilesystems = true;

        # your original knobs, preserved
        cores = 2;
        diskSize = 40960; # 40 GiB
        memorySize = 4096;
        graphics = false; # headless

        sharedDirectories.repo = {
          source = "/home/mhr/nixos"; # host path
          target = "/mnt/host/nixos"; # inside the VM
          # writable = true;
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
