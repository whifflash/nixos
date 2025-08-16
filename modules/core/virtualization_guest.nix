{
  pkgs,
  config,
  lib,
  ...
}: let
  id = "virtualization_guest";
  cfg = config.${id};
in {
  options.${id} = {
    enable = lib.mkEnableOption "enables ${id} profile";
  };

  config = lib.mkIf cfg.enable {
    # VM specific stuff
    virtualisation = {
      guest = {
        enable = true;
        clipboard = true;
        vboxsf = true;
      };
      virtualbox.host.enableExtensionPack = true;
    };

    users.users.mhr.extraGroups = ["vboxusers" "vboxsf"];
  };
}
