{ inputs, lib, config, pkgs, ... }:
let 
id = "role_hardware-development";
cfg = config.${id};
in 
{

  options.${id} = {
    enable = lib.mkEnableOption "enables ${id} profile";
  };

  config = lib.mkIf cfg.enable {


    environment.systemPackages = with pkgs; [
    kicad
    ];
  };


}
