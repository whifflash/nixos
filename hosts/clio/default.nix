{
  inputs,
  lib,
  pkgs,
  ...
}: {
  imports = [
    # ../mia/hardware-configuration.nix
    inputs.sops-nix.nixosModules.sops
    ./vm.nix
    ./domain.nix
    ./secrets.nix
    ./services.nix
  ];

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
  ];

  system.stateVersion = "24.05";
}
