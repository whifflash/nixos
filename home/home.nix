{
  pkgs,
  lib,
  osConfig,
  # inputs,
  ...
}:
# let
#   gruvboxPlus = import ./themes/icons/gruvbox-plus.nix { inherit pkgs; };
# in
let
  swaySwitch = osConfig.programs.sway.enable or false; # read the host switch
in {
  imports = [
    ./packages.nix
    ./apps/firefox
    ./git.nix
    ./ssh.nix

    # Tokens for themeing
    ./themes/tokens.nix

    # Then token consumers
    ./themes/stylix-bridge.nix
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
      # catppucin-frappe everforest-dark gruvbox-dark gruvbox-light kanagawa nord solarized-dark tokyonight-storm
      scheme = "everforest-dark"; # or "gruvbox-light"
      writeWaybarPalette = true; # generates ~/.config/waybar/palette.css
      writeWofiPalette = true; # generates ~/.config/wofi/palette.css
      writeZshEnv = true; # generates ~/.config/theme/env
    };

    swayTheme = lib.mkIf swaySwitch {
      enable = true;
      wallpapersDir = ../media/wallpapers;
      wallpaper = "anna-scarfiello.jpg";
      wallpaperMode = "stretch"; # stretch fill
      swaylock.image = ../media/wallpapers/village.jpg;
    };

    tmux = {
      enable = true;
      # terminal = "tmux-256color";
      # historyLimit = 200000;
      # shell = "${pkgs.zsh}/bin/zsh";
      # mouse = true;
      # escapeTime = 10;
    };
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
  }; # end of home = {};

  programs = {
    home-manager.enable = true; # let home manager manage itself

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

  dconf.settings = {
    "org/gnome/desktop/background" = {
      picture-uri-dark = "file://${pkgs.nixos-artwork.wallpapers.nineish-dark-gray.src}";
    };
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };

  # Wayland, X, etc. support for session vars
  # systemd.user.sessionVariables = config.home-manager.users.mhr.home.sessionVariables;

  # qt = {
  #   enable = true;
  #   platformTheme.name = "qtct";
  #   style.name = "kvantum";
  # };

  xdg.configFile = {
    "Kvantum/kvantum.kvconfig".text = ''
      [General]
      theme=WhiteSur
    '';

    "Kvantum/WhiteSurDark".source = "${pkgs.whitesur-kde}/share/Kvantum/WhiteSur";
  };

  gtk = {
    enable = true;

    # theme = {
    #   name = "WhiteSur-Dark";
    #   package = pkgs.whitesur-gtk-theme;
    # };
    # cursorTheme = {
    #   package = pkgs.bibata-cursors;
    #   name = "Bibata-Modern-Ice";
    # };
    # iconTheme = {
    #   package = pkgs.whitesur-icon-theme;
    #   name = "WhiteSur-Dark"; # "WhiteSur-Dark" "WhiteSur-Light"
    # };
  };
}
