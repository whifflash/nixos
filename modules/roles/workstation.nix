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
    neovim
    thunderbird
    joplin
    joplin-desktop
    tmux
    alacritty
    firefox
    chromium
    ];

    fonts.packages = with pkgs; [
    font-awesome
    powerline-fonts
    powerline-symbols
    (nerdfonts.override { fonts = [ "NerdFontsSymbolsOnly" ]; })
    ];

    programs.gnupg.agent = {
      enable = true;
      pinentryPackage = with pkgs; pinentry-all;
      enableSSHSupport = true;
    };

  };

}
