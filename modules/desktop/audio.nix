{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: let
  id = "desktop_audio";
  cfg = config.${id};
in {
  options.${id} = {
    enable = lib.mkEnableOption "enables ${id} profile";
  };

  config = lib.mkIf cfg.enable {
    services.pulseaudio.enable = false;

    security.rtkit.enable = true;
    # Enable sound with pipewire.
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };
}
