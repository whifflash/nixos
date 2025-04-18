# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, config, pkgs, specialArgs,... }:

{
  imports =
  [ # Include the results of the hardware scan.
  ./hardware-configuration.nix
  ./../../modules/modules.nix  
  inputs.home-manager.nixosModules.default
  inputs.stylix.nixosModules.stylix
  inputs.sops-nix.nixosModules.sops
  ];
  sops.defaultSopsFile = ../../secrets/secrets.yaml;
  sops.defaultSopsFormat = "yaml";

  sops.age.keyFile = "/home/mhr/.config/sops/age/keys.txt";

  sops.secrets."wireguard/${specialArgs.hostname}/keys/private" = {
    owner = "systemd-network";
  };
  sops.secrets."wireguard/vps/keys/public" = {
    owner = config.users.users."systemd-network".name;
  };  
  sops.secrets."network-manager.env" = {
    owner = config.users.users."systemd-network".name;
  };



  # ${specialArgs.hostname}

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "mia"; # Define your hostname.

  # Enable networking
  networking.networkmanager.enable = true;

  # Put in laptop role
  programs.light.enable = true;

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
    # vpl-gpu-rt # or intel-media-sdk for QSV
    ];
  };

  hardware.hackrf = {
    enable = true;
  };


  desktop_gdm.enable = false;
  desktop_sddm.enable = true;
  desktop_gnome.enable = false;
  desktop_greetd.enable = false;
  desktop_hyprland.enable = false;
  desktop_sway.enable = true;
  desktop_audio.enable = true;
  base_packages.enable = true;
  base_options.enable = true;
  user_options.enable = true;

  virtualization_guest.enable = false;
  role_workstation.enable = true;
  role_hardware-development.enable = true;
  role_tailscale-node.enable = true;


  # Enable the X11 windowing system.
  services.xserver.enable = true;

      system.stateVersion = "24.11";

    }
