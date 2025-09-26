{modulesPath, ...}: {
  virtualisation = {
    # Provide a VM variant that brings in the qemu-vm machinery
    vmVariant = {
      imports = [(modulesPath + "/virtualisation/qemu-vm.nix")];
      virtualisation = {
        cores = 2;
        memorySize = 2048;
        # optional:
        graphics = false; # headless

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
