{ pkgs, config, lib, ... }:
let 
id = "base_packages";
cfg = config.${id};
in 
{
options.${id} = {
enable = lib.mkEnableOption "enables ${id} profile";
};

config = lib.mkIf cfg.enable {
environment.systemPackages = with pkgs; [
neovim
git
gopass
gnupg
pinentry-curses
sops
gqrx
];
};



}
