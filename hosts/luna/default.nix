# hosts/luna/default.nix
# NixOS host configuration for "luna" (Jovian gaming box, nixos-unstable).
# Desktop/theming knobs are in ./config.toml (nix-desktop shared layer).
{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./../../modules/modules.nix
    ./../../modules/hardware/ds5-bridge-wakeup.nix
    ./../../modules/roles/jovian-gaming.nix
  ];

  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    age.keyFile = "/home/mhr/.config/sops/age/keys.txt";
  };
  sops.secrets = {
    "wireguard/vps/keys/public" = {
      owner = config.users.users."systemd-network".name;
    };
    "network-manager.env" = {
      owner = config.users.users."systemd-network".name;
    };
    # "git/userName" = {};
    # "git/userEmail" = {};
  };

  # Bootloader.
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  networking.hostName = "luna"; # Define your hostname.

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

  # Greeter: none — Jovian's autostart owns the session (its assertion requires
  # desktop_sddm off). The shared layer would otherwise provide a greetd
  # fallback; keep it off here so Jovian stays in charge of the display.
  desktop_sddm.enable = false;
  # mkForce: the shared wayland-common enables greetd whenever SDDM is off.
  services.greetd.enable = lib.mkForce false;

  # Desktop environments: sway is switched from ./config.toml [features]; the
  # stock "sway" session name is kept (desktop.sway.replaceDefaultSession =
  # false) because Jovian's Switch-to-Desktop references it.
  desktop_budgie.enable = false;
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
  role_jovian_gaming = {
    enable = true;
    autoStart = true;
    user = "mhr";
    desktopSession = "sway";
  };
  role_hardware-development.enable = false;
  role_tailscale-node.enable = true;
  remote_admin_ssh = {
    enable = true;
    allowLanAccess = true;
  };
  role_laptop.enable = false;

  hardware_ds5_bridge_wakeup = {
    enable = true;
    enableParentWakePath = true;
    suspendMode = null;
  };

  # Scalars come from ./config.toml through nix-desktop's hostcfg-feed; only the
  # nix-path values live here.
  ui.theme = {
    wallpapersDir = ../../media/wallpapers;
    swaylock.image = ../../media/wallpapers/village.jpg;
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

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
    supportedFeatures = [
      "kvm"
      "big-parallel"
      "nixos-test"
    ];

    sshKey = "/root/.ssh/builder_ed25519";
  };
}
