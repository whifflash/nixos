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
    virtualization = {
        virtualbox.host.enableExtensionPack = true;
        virtualbox.guest.enable = true;
        virtualbox.guest.clipboard = true;
        virtualbox.guest.vboxsf = true;

    };

    users.users.mhr.extraGroups = ["vboxusers" "vboxsf"];
  };
}
