{ inputs, lib, config, ... }:
let 
id = "desktop_lightdm";
cfg = config.${id};
in 
{

  options.${id} = {
    enable = lib.mkEnableOption "enables ${id} profile";
  };

  config = lib.mkIf cfg.enable {
# Enable the X11 windowing system.
services.xserver.enable = true;
services.xserver.displayManager.lightdm.enable = true;
};

}
