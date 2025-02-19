{ inputs, lib, config, pkgs, ... }:
let 
id = "desktop_hyprland";
cfg = config.${id};
in 
{

  options.${id} = {
    enable = lib.mkEnableOption "enables ${id} profile";
  };

  config = lib.mkIf cfg.enable {

  #   nix.settings = {
  #   substituters = ["https://hyprland.cachix.org"];
  #   trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="];
  # };

  #   programs.hyprland = {
  #     enable = true;
  #     xwayland.enable = true;
  #     # set the flake package
  #     package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
  #     # make sure to also set the portal package, so that they are in sync
  #     portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
  #   };

    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
    };

    programs.waybar = {
      enable = true;
    };

    # programs.hyprland.enable = true;
    # environment.sessionVariables.NIXOS_OZONE_WL = "1";
    # environment.sessionVariables.WLR_NO_HARDWARE_CURSORS = "1";

    environment.systemPackages = with pkgs; [
    waybar
    eww
    wofi
    kitty
    hyprpicker
    hyprcursor
    hyprlock
    hypridle
    hyprpaper

    # whitesur-gtk-theme
    # whitesur-cursors
    # whitesur-icon-theme
    ];
  };


}
