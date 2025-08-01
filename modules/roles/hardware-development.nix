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

  # hardware.hackrf = {
  #   enable = true;
  # };



    environment.systemPackages = with pkgs; [
    kicad
    betaflight-configurator
    gqrx
    ];

  };


}
