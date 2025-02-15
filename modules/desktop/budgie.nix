{ inputs, lib, config, ... }:
let 
id = "desktop_budgie";
cfg = config.${id};
in 
{

  options.${id} = {
    enable = lib.mkEnableOption "enables ${id} profile";
  };

  config = lib.mkIf cfg.enable {
  	services.xserver.desktopManager.budgie.enable = true;
  };
  
}
