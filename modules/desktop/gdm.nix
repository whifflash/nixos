{ inputs, lib, config, pkgs, ... }:
let 
id = "desktop_gdm";
cfg = config.${id};
in 
{

  options.${id} = {
    enable = lib.mkEnableOption "enables ${id} profile";
  };

  config = lib.mkIf cfg.enable {
  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.gdm.enable = true;
  };

}
