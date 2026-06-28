# hosts/clio/common.nix
{pkgs, ...}: {
  imports = [
    ../../services
    ./secrets.nix
  ];

  # Clio keeps serving the existing hub. Other services are enabled by their
  # current host while they are migrated one at a time.
  infra.services.hub.enable = true;

  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    # builders = "ssh-ng://YOUR_LINUX_USER@icarus x86_64-linux - 4 1 big-parallel,kvm";
  };

  boot.loader = {
    grub.enable = false;
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  time.timeZone = "Europe/Berlin";

  users = {
    mutableUsers = false;

    users.mhr = {
      isNormalUser = true;
      extraGroups = ["wheel"]; # Enable ‘sudo’ for the user.
      hashedPassword = "$6$9uqlmNuc/3SSq37g$8iDD2YElaIpYRBywRKQm/jRYA2KjWjc9BQpSE9hgmgnGVYdgGanhZtFA4AePG8IKBM45OgAAuQZT4IKHCAevY."; #  mkpasswd -m sha-512
      openssh.authorizedKeys.keys = [];
    };

    groups.nginx = {};
  };

  networking = {
    hostName = "clio";
    useDHCP = true;
    firewall = {
      enable = true;
      # Retain the existing Clio policy until the corresponding services are
      # migrated into shared modules and can own their ports themselves.
      allowedTCPPorts = [
        22
        80
        443
        1883
        6789
        8080
      ];
      allowedUDPPorts = [
        3478
        10001
      ];
    };
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };

  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [
    git
    sops
    vim
  ];
}
