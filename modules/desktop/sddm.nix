{ inputs, lib, config, pkgs, ... }:
let 
id = "desktop_sddm";
cfg = config.${id};
in 
{

  options.${id} = {
    enable = lib.mkEnableOption "enables ${id} profile";
  };

  config = lib.mkIf cfg.enable {
  # Enable the sddm Display Manager.
   services.xserver.displayManager.sddm.enable = true; 
  };

}
