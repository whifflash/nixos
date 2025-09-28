{
  inputs,
  lib,
  pkgs,
  ...
}: {
  imports = [
    inputs.sops-nix.nixosModules.sops
    inputs.disko.nixosModules.disko

    ./options.nix # defines clio.isVM and clio.enableDisko
    ./storage.nix # uses the flags above
    ./secrets.nix
    ./domain.nix
    ./services.nix
    ./vm.nix # VM-only overrides last
  ];

  # Defaults for the real host (the VM will override them via vm.nix)
  clio.enableDisko = true;
  clio.isVM = false;

  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    # builders = "ssh-ng://YOUR_LINUX_USER@icarus x86_64-linux - 4 1 big-parallel,kvm";
  };

  users.mutableUsers = false;

  users.users.mhr = {
    isNormalUser = true;
    extraGroups = ["wheel"]; # Enable ‘sudo’ for the user.
    hashedPassword = "$6$9uqlmNuc/3SSq37g$8iDD2YElaIpYRBywRKQm/jRYA2KjWjc9BQpSE9hgmgnGVYdgGanhZtFA4AePG8IKBM45OgAAuQZT4IKHCAevY."; #  mkpasswd -m sha-512
  };

  networking.hostName = "clio";
  environment.systemPackages = with pkgs; [
    git
    sops
    vim
  ];

  system.stateVersion = "24.05";
}
