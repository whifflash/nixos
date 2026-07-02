{pkgs, ...}: {
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
    ../../services
  ];

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  networking = {
    hostName = "icarus";
    networkmanager.enable = true;
  };

  nix.settings.experimental-features = [
    "flakes"
    "nix-command"
  ];

  time.timeZone = "Europe/Berlin";

  environment.systemPackages = with pkgs; [
    git
    vim
  ];

  users = {
    mutableUsers = false;

    users.mhr = {
      isNormalUser = true;
      description = "mhr";
      extraGroups = ["wheel"];

      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILf46c7nmSRrmr/6iZ0ozwxSaGyQa9YJjmCXyu3+w/HN mhr@mia"
      ];
    };
  };

  security.sudo.wheelNeedsPassword = false;

  services.openssh = {
    enable = true;
    openFirewall = true;

    settings = {
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # nixos-anywhere --copy-host-keys preserves this key across installation.
  # The corresponding public key must be a recipient for infrastructure.yaml.
  sops = {
    age = {
      generateKey = false;
      keyFile = "/var/lib/sops-nix/key.txt";
    };
  };

  infra.services.gitea = {
    enable = true;
    disableRegistration = true;
  };

  zramSwap.enable = true;

  system.stateVersion = "26.05";
}
