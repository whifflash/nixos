# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./../../modules/modules.nix  
      inputs.home-manager.nixosModules.default
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "mia"; # Define your hostname.

  # Enable networking
  networking.networkmanager.enable = true;

  desktop_gdm.enable = true;
  desktop_gnome.enable = true;
  desktop_greetd.enable = false;
  desktop_hyprland.enable = true;
  desktop_sway.enable = false;
  desktop_audio.enable = true;
  base_packages.enable = true;
  base_options.enable = true;
  virtualization_guest.enable = false;
  role_workstation.enable = true;
  role_hardware-development.enable = true;

  # Enable the X11 windowing system.
  services.xserver.enable = true;


  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.mhr = {
    isNormalUser = true;
    description = "mhr";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
    #  thunderbird
    ];
  };

  system.stateVersion = "24.11";

}
