{
  lib,
  config,
  ...
}: let
  id = "role_laptop";
  cfg = config.${id};
in {
  options.${id} = {
    enable = lib.mkEnableOption "enables ${id} profile";
  };

  config = lib.mkIf cfg.enable {
    # programs.light.enable = true;
    # TODO The corresponding package was removed from nixpkgs due to being unmaintained upstream. `brightnessctl` and `hardware.acpilight` offer replacements.

    # hardware.hackrf = {
    #   enable = true;
    # };

    # environment.systemPackages = with pkgs; [
    # kicad
    # betaflight-configurator
    # ];
  };
}
