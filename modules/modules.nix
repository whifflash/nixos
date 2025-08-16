{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./core/base_options.nix
    ./core/base_packages.nix
    ./core/virtualization_guest.nix
    ./core/user_options.nix
    ./desktop/lightdm.nix
    ./desktop/sddm.nix
    ./desktop/gdm.nix
    ./desktop/greetd.nix
    ./desktop/hyprland.nix
    ./desktop/budgie.nix
    ./desktop/gnome.nix
    ./desktop/sway.nix
    ./desktop/audio.nix
    ./roles/workstation.nix
    ./roles/hardware-development.nix
    ./roles/tailscale-node.nix
    ./roles/laptop.nix
    ./setups/3gpplab.nix
  ];
}
