{
  lib,
  config,
  pkgs,
  ...
}: let
  sw = config.programs.sway.enable or false; # read the host switch
  # id = "desktop_sway";
  # cfg = config.${id};
in {
  options."sway" = {
    enable = lib.mkEnableOption "enables sway and corresponding helper programs";
  };

  config = lib.mkIf sw {
    environment = {
      sessionVariables.NIXOS_OZONE_WL = "1";
      sessionVariables.WLR_NO_HARDWARE_CURSORS = "1";

      systemPackages = with pkgs; [
        grim # screenshot functionality
        slurp # screenshot functionality
        wl-clipboard # wl-copy and wl-paste for copy/paste from stdin / stdout
        mako # notification system developed by swaywm maintainer
        # swaynotificationcenter
        waybar
        wofi
        swaylock-effects
        libnotify
        gnome-weather
        pavucontrol
      ];
    };

    # Enable the gnome-keyring secrets vault.
    # Will be exposed through DBus to programs willing to store secrets.
    services.gnome.gnome-keyring.enable = true;

    # enable Sway window manager
    # programs.sway = {
    #   enable = true;
    #   wrapperFeatures.gtk = true;
    # };
  }; # end of switch
}
