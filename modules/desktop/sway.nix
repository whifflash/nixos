{ inputs, lib, config, pkgs, ... }:
let 
id = "desktop_sway";
cfg = config.${id};
in 
{

  options.${id} = {
    enable = lib.mkEnableOption "enables ${id} profile";
  };

  config = lib.mkIf cfg.enable {

    environment.sessionVariables.NIXOS_OZONE_WL = "1";
    environment.sessionVariables.WLR_NO_HARDWARE_CURSORS = "1";

    # Enable the gnome-keyring secrets vault. 
    # Will be exposed through DBus to programs willing to store secrets.
    services.gnome.gnome-keyring.enable = true;

    # enable Sway window manager
    programs.sway = {
      enable = true;
      wrapperFeatures.gtk = true;
    };

    environment.systemPackages = with pkgs; [
    grim # screenshot functionality
    slurp # screenshot functionality
    wl-clipboard # wl-copy and wl-paste for copy/paste from stdin / stdout
    mako # notification system developed by swaywm maintainer
    # swaynotificationcenter
    waybar
    wofi
    swaylock-effects
    libnotify
    gnome-wather
    pavucontrol
    ];
  };
}
