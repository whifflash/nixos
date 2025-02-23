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
    blueberry
    ];

    environment.sessionVariables.GTK_THEME = "Adwaita:dark";

      hardware.bluetooth.enable = true; # enables support for Bluetooth
  hardware.bluetooth.powerOnBoot = true; # powers up the default Bluetooth controller on boot

    fonts.packages = with pkgs; [
    font-awesome
    powerline-fonts
    powerline-symbols
    (nerdfonts.override { fonts = [ "NerdFontsSymbolsOnly" ]; })
    ];

    programs.gnupg.agent = {
      enable = true;
      pinentryPackage = with pkgs; pinentry-gnome3;
      enableSSHSupport = true;
    };

  };

}
