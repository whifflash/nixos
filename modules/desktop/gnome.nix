{
  inputs,
  lib,
  config,
  ...
}: let
  id = "desktop_gnome";
  cfg = config.${id};
in {
  options.${id} = {
    enable = lib.mkEnableOption "enables ${id} profile";
  };

  config = lib.mkIf cfg.enable {
    services.xserver.desktopManager.gnome.enable = true;
  };
}
