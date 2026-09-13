{ ... }:
{
  # Reusable NixOS modules, each gated by its own `<id>.enable` option. The
  # desktop layer (ui.* options, sway/niri/wayland-common with the greetd
  # fallback) comes from the nix-desktop flake input (flake-modules/nixos).
  imports = [
    ./attic/client.nix
    ./core/base_options.nix
    ./core/base_packages.nix
    ./core/virtualization_guest.nix
    ./core/user_options.nix
    ./core/ssh.nix
    ./core/remote-admin-ssh.nix
    ./desktop/lightdm.nix
    ./desktop/sddm.nix
    ./desktop/gdm.nix
    ./desktop/hyprland.nix
    ./desktop/budgie.nix
    ./desktop/gnome.nix
    ./desktop/audio.nix
    ./roles/workstation.nix
    ./roles/hardware-development.nix
    ./roles/tailscale-node.nix
    ./roles/laptop.nix
    ./setups/3gpplab.nix
  ];
}
