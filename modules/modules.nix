{ pkgs, lib, ... }:
{
  imports = [
    ./core/base_options.nix 
    ./core/base_packages.nix
    ./core/virtualization_guest.nix 
    ./desktop/lightdm.nix
    ./desktop/greetd.nix
    ./desktop/hyprland.nix
    ./desktop/budgie.nix
    ./desktop/gnome.nix 
    ./desktop/sway.nix
    ./desktop/audio.nix
    ./roles/workstation.nix
    ./roles/hardware-development.nix
    ./setups/3gpplab.nix   
  ];

}