{
  pkgs,
  lib,
  osConfig,
  ...
}: let
  # Returns a PATH; falls back to `def` if host value is missing, null, or not a path.
  getPathOr = attrs: def: let
    v = lib.attrByPath attrs osConfig null;
  in
    if v != null && builtins.isPath v
    then v
    else def;

  # Returns a STRING; falls back to `def` if host value is missing, null, or not a string.
  getStrOr = attrs: def: let
    v = lib.attrByPath attrs osConfig null;
  in
    if v != null && builtins.isString v
    then v
    else def;

  swaySwitch = osConfig.programs.sway.enable or false;

  # Path defaults (literals, not strings)
  defaultWallpapersDir = ../media/wallpapers;
  defaultSwaylockImage = ../media/wallpapers/village.jpg;

  # Read from host, never yielding null for path-typed fields
  hostWallpapersDir = getPathOr ["ui" "theme" "wallpapersDir"] defaultWallpapersDir;
  hostSwaylockImage = getPathOr ["ui" "theme" "swaylockImage"] defaultSwaylockImage;

  # String-typed fields
  hostWallpaper = getStrOr ["ui" "theme" "wallpaper"] "anna-scarfiello.jpg";
  hostWallpaperMode = getStrOr ["ui" "theme" "wallpaperMode"] "stretch";
  # # Scheme: optional; don't set it if host didn't specify it
  # hostScheme = lib.attrByPath ["ui" "theme" "scheme"] osConfig null;
in {
  imports = [
    ./packages.nix
    ./apps/firefox
    ./git.nix
    ./ssh.nix

    # Tokens for themeing
    ./themes/tokens.nix

    # Then token consumers
    ./themes/sway-colors.nix
    ./themes/sway-theme.nix

    ./apps/sway.nix
    ./apps/zsh.nix
    ./apps/tmux.nix
  ];

  wayland.windowManager.sway = lib.mkIf swaySwitch {
    enable = true;
  };

  hm = {
    theme = {
      enable = true;
      # scheme = lib.mkDefault hostScheme; # null is fine; token layer may default
      writeWaybarPalette = true;
      writeWofiPalette = true;
      writeZshEnv = true;
    };

    swayTheme = lib.mkIf swaySwitch {
      enable = true;
      wallpapersDir = lib.mkDefault hostWallpapersDir; # PATH
      wallpaper = lib.mkDefault hostWallpaper; # STRING
      wallpaperMode = lib.mkDefault hostWallpaperMode; # STRING
      swaylock.image = hostSwaylockImage; # PATH
    };

    tmux.enable = true;
  };

  home = {
    username = "mhr";
    homeDirectory = "/home/mhr";

    stateVersion = "24.11"; # Please read the comment before changing.

    file = {
      # ".config/hypr/hyprland.conf".source = ./dotfiles/.config/hypr/hyprland.conf;
      ".config/wofi/style.css".source = ./dotfiles/.config/wofi/style.css;

      ".config/wofi/config".source = ./dotfiles/.config/wofi/config;
      ".config/wofi/gopass.switcher.sh".source = ./dotfiles/.config/wofi/gopass.switcher.sh;
      ".config/wofi/gopass.launcher.sh".source = ./dotfiles/.config/wofi/gopass.launcher.sh;
      ".config/gopass/stores.local".source = ./dotfiles/.config/gopass/stores.local;

      # ".config/gtk-4.0/gtk.css".source = ./dotfiles/.config/gtk-4.0/gtk.css;
      # ".config/gtk-3.0/gtk.css".source = ./dotfiles/.config/gtk-3.0/gtk.css;

      ".config/waybar/style.css".source = ./dotfiles/.config/waybar/style.css;
      # ".config/waybar/colors.css".source = ./dotfiles/.config/waybar/colors.css;
      ".config/waybar/config".source = ./dotfiles/.config/waybar/config;
      ".config/waybar/modules.json".source = ./dotfiles/.config/waybar/modules.json;
      ".config/waybar/ornamental.json".source = ./dotfiles/.config/waybar/ornamental.json;
      ".config/waybar/ornamental.css".source = ./dotfiles/.config/waybar/ornamental.css;
      ".config/waybar/launch_waybar.sh".source = ./dotfiles/.config/waybar/launch_waybar.sh;
      # ".config/swaylock/config".source = ./dotfiles/.config/swaylock/config;
      ".config/sway/tmux/tmux_reattach.sh".source = ./dotfiles/.config/sway/tmux/tmux_reattach.sh;

      # Moved to home manager
      # ".config/sway/config".source = ./dotfiles/.config/sway/config;
    };

    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      GTK_THEME = "Adwaita:dark";
    };

    # packages = ["qt6ct"];
  }; # end of home = {};

  programs = {
    home-manager.enable = true; # let home manager manage itself

    # kvantum.enable = true;

    neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      vimdiffAlias = true;
      plugins = with pkgs.vimPlugins; [
        # nvim-lspconfig
        # nvim-treesitter.withAllGrammars
        # plenary-nvim
        # gruvbox-material
      ];
    };
  }; # end of programs = {};

  services = {
    gpg-agent = {
      enable = true;
      enableSshSupport = true;
      pinentry.package = pkgs.pinentry-gnome3;
    };

    flameshot = {
      enable = true;
      settings.General = {
        showStartupLaunchMessage = false;
        saveLastRegion = true;
      };
    };
  }; # end of services = {};

  # dconf.settings = {
  #   "org/gnome/desktop/background" = {
  #     picture-uri-dark = "file://${pkgs.nixos-artwork.wallpapers.nineish-dark-gray.src}";
  #   };
  #   "org/gnome/desktop/interface" = {
  #     color-scheme = "prefer-dark";
  #   };
  # };

  # Wayland, X, etc. support for session vars
  # systemd.user.sessionVariables = config.home-manager.users.mhr.home.sessionVariables;

  # xdg.configFile = {
  #   "Kvantum/kvantum.kvconfig".text = ''
  #     [General]
  #     theme=WhiteSur
  #   '';

  #   "Kvantum/WhiteSurDark".source = "${pkgs.whitesur-kde}/share/Kvantum/WhiteSur";
  # };

  # programs.kvantum.enable = true;

  gtk = {
    enable = true;
  };
}
