{ pkgs, config, lib, ... }:
let 
id = "virtualization_guest";
cfg = config.${id};
in 
{

  options.${id} = {
    enable = lib.mkEnableOption "enables ${id} profile";
  };

  config = lib.mkIf cfg.enable {

    # VM specific stuff
    virtualisation.virtualbox.host.enableExtensionPack = true;
    virtualisation.virtualbox.guest.enable = true;
    virtualisation.virtualbox.guest.clipboard = true;
    virtualisation.virtualbox.guest.vboxsf = true;
    users.users.mhr.extraGroups = ["vboxusers" "vboxsf"];

  };

}