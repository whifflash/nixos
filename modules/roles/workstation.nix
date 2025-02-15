{ inputs, lib, config, pkgs, ... }:
let 
id = "role_workstation";
cfg = config.${id};
in 
{

  options.${id} = {
    enable = lib.mkEnableOption "enables ${id} profile";
  };

  config = lib.mkIf cfg.enable {

    # Needed for sublime
    nixpkgs.config.permittedInsecurePackages = [
    "openssl-1.1.1w"
    ];
    environment.systemPackages = with pkgs; [
    sublime4
    thunderbird
    joplin
    joplin-desktop
    tmux
    alacritty
    gopass
    ];
  };

}
