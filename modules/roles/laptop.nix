{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: let
  id = "role_laptop";
  cfg = config.${id};
in {
  options.${id} = {
    enable = lib.mkEnableOption "enables ${id} profile";
  };

  config = lib.mkIf cfg.enable {
    programs.light.enable = true;

    # hardware.hackrf = {
    #   enable = true;
    # };

    # environment.systemPackages = with pkgs; [
    # kicad
    # betaflight-configurator
    # ];
  };
}
