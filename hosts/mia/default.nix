# hosts/mia/default.nix
# NixOS host configuration for "mia", adapted for flake-based imports.
{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./../../modules/modules.nix
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x270
  ];

  # Recommended extras (safe defaults)

  services = {
    fwupd.enable = true; # LVFS firmware updates
    fstrim.enable = true; # SSD TRIM weekly
    power-profiles-daemon.enable = true;
  };

  hardware = {
    cpu.intel.updateMicrocode = lib.mkDefault true;
    enableRedistributableFirmware = lib.mkDefault true;

    trackpoint = {
      enable = true;
      speed = 190; # 0–255
      sensitivity = 130; # 0–255
    };
  };

  # alternatively tlp...
  # services.tlp.enable = true;
  # services.tlp.settings = {
  #   START_CHARGE_THRESH_BAT0 = 75;
  #   STOP_CHARGE_THRESH_BAT0  = 85;
  # };

  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    age.keyFile = "/home/mhr/.config/sops/age/keys.txt";
    secrets = {
      "wireguard/vps/keys/public" = {owner = config.users.users."systemd-network".name;};
      "network-manager.env" = {owner = config.users.users."systemd-network".name;};
      # "git/userName" = {};
      # "git/userEmail" = {};
    };
  };

  # Bootloader.
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  networking.hostName = "mia"; # Define your hostname.

  # Enable networking
  networking.networkmanager.enable = true;

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      # vpl-gpu-rt # or intel-media-sdk for QSV
    ];
  };

  # Ensure the user exists at the system level
  users.users.mhr = {
    isNormalUser = true;
    # …other user options…
  };

  # Home Manager user binding for this host:
  home-manager.users.mhr = import ../../home/home.nix;
  # or imports = [ ../../home/ssh.nix ../../home/shell.nix ];

  # Greeter
  desktop_sddm.enable = true;
  desktop_greetd.enable = false;

  #Desktop Environments
  programs.sway.enable = true;
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
  role_tailscale-node.enable = true;
  role_laptop.enable = true;

  # Enable the X11 windowing system.
  services.xserver.enable = true;
  system.stateVersion = "24.11";

  # Attic cache client (reads endpoint/key/token from secrets)
  attic_client = {
    enable = true;
    secretsFile = ../../secrets/attic.yaml; # encrypted YAML
    addOfficialCache = true;
    fallback = true;
  };

  # Optional: use the home server as remote builder
  attic_remote = {
    enable = true;
    hostName = "attic.c4rb0n.cloud";
    sshUser = "mhr";
    system = "x86_64-linux";
    maxJobs = 8;
  };
}
