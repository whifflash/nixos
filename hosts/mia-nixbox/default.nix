# hosts/mia-nixbox/default.nix
# NixOS host configuration for "mia", adapted for flake-based imports.
{
  # inputs,
  pkgs,
  config,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./../../modules/modules.nix
    # inputs.home-manager.nixosModules.default
  ];

  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    age.keyFile = "/home/mhr/.config/sops/age/keys.txt";
    secrets = {
      "wireguard/vps/keys/public" = {owner = config.users.users."systemd-network".name;};
      "network-manager.env" = {owner = config.users.users."systemd-network".name;};
    };
  };

  # Bootloader.

  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
    useOSProber = true;
  };

  hardware.graphics.enable = true;

  users.users.mhr = {
    isNormalUser = true;
    description = "mhr";
    extraGroups = ["networkmanager" "wheel" "vboxsf"];
    packages = with pkgs; [
      #  thunderbird
    ];
  };

  # Home Manager user binding for this host:
  home-manager.users.mhr = import ../../home/home.nix;
  # or imports = [ ../../home/ssh.nix ../../home/shell.nix ];

  services = {
    # Enable the X11 windowing system.
    xserver.enable = true;

    # Configure keymap in X11
    xserver.xkb = {
      layout = "us";
      variant = "";
    };

    # Enable CUPS to print documents.
    printing.enable = true;
  };

  networking.hostName = "mianixbox"; # Define your hostname.

  # Enable networking
  networking.networkmanager.enable = true;

  # Greeter
  desktop_sddm.enable = true;
  desktop_greetd.enable = false;

  #Desktop Environments
  programs.sway.enable = false;
  desktop_budgie.enable = true;
  desktop_gdm.enable = false;
  desktop_gnome.enable = false;
  desktop_hyprland.enable = false;

  #Audio
  desktop_audio.enable = true;

  base_packages.enable = true;
  base_options.enable = true;
  user_options.enable = true;

  virtualization_guest.enable = false;
  role_workstation.enable = true;
  role_hardware-development.enable = false;

  system.stateVersion = "24.11"; # Did you read the comment?

  # Attic cache client (reads endpoint/key/token from secrets)
  attic_client = {
    enable = true;
    secretsFile = ../../secrets/attic.yaml; # encrypted YAML
    addOfficialCache = true;
    fallback = true;
  };

  attic_remote = {
    enable = true;
    hostName = "attic.c4rb0n.cloud"; # or "10.20.31.41"
    sshUser = "mhr";

    system = "x86_64-linux";
    maxJobs = 8;
    speedFactor = 2;
    supportedFeatures = ["kvm" "big-parallel" "nixos-test"];

    sshKey = "/root/.ssh/builder_ed25519";
  };
}
