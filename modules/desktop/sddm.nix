{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: let
  id = "desktop_sddm";
  cfg = config.${id};
in {
  options.${id} = {
    enable = lib.mkEnableOption "enables ${id} profile";
  };

  config = lib.mkIf cfg.enable {
    # Enable the sddm Display Manager.
    services.displayManager.sddm = {
      enable = true;
      theme = "${import ./themes/sddm-sugar-dark.nix {inherit pkgs;}}";
    };

    environment.systemPackages = with pkgs; [
      libsForQt5.qt5.qtquickcontrols2
      libsForQt5.qt5.qtgraphicaleffects
    ];
  };
}
