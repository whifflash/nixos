{modulesPath, ...}: {
  # Provide a VM variant that brings in the qemu-vm machinery
  virtualisation.vmVariant = {
    imports = [(modulesPath + "/virtualisation/qemu-vm.nix")];
    virtualisation.cores = 2;
    virtualisation.memorySize = 2048;
    # optional:
    # virtualisation.graphics = false;  # headless
  };
}
