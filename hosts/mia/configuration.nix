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
      inputs.stylix.nixosModules.stylix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "mia"; # Define your hostname.

  # Enable networking
  networking.networkmanager.enable = true;

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      # vpl-gpu-rt # or intel-media-sdk for QSV
    ];
  };

  desktop_gdm.enable = true;
  desktop_gnome.enable = true;
  desktop_greetd.enable = false;
  desktop_hyprland.enable = true;
  desktop_sway.enable = false;
  desktop_audio.enable = true;
  base_packages.enable = true;
  base_options.enable = true;
  user_options.enable = true;

  virtualization_guest.enable = false;
  role_workstation.enable = true;
  role_hardware-development.enable = true;

  # Enable the X11 windowing system.
  services.xserver.enable = true;
  # stylix = {
  #   enable = true;
  #   base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";
  #   image = ../../media/wallpapers/anna-scarfiello.jpg;
  # };


  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

#   users.users.mhr.isNormalUser = true;
#   home-manager.users.mhr = { pkgs, ... }: {
#   home.packages = [ pkgs.atool pkgs.httpie ];
#   programs.bash.enable = true;

#   # The state version is required and should stay at the version you
#   # originally installed.
#   home.stateVersion = "24.05";
# };

  system.stateVersion = "24.11";

}
