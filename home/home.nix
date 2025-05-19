{ config, pkgs, work, ... }:

let 
  gruvboxPlus = import ./themes/icons/gruvbox-plus.nix { inherit pkgs; };
in
{

    imports = [
    ./packages.nix
    ./apps/firefox
    ./git.nix
    ./ssh.nix
    ];
  home.username = "mhr";
  home.homeDirectory = "/home/mhr";

  home.stateVersion = "24.05"; # Please read the comment before changing.



    home.file = {
      ".config/hypr/hyprland.conf".source = ./dotfiles/.config/hypr/hyprland.conf;
      # ".config/wofi/style.css".source = ./dotfiles/.config/wofi/style.css; 
      ".config/wofi/config".source = ./dotfiles/.config/wofi/config; 
      ".config/wofi/gopass.switcher.sh".source = ./dotfiles/.config/wofi/gopass.switcher.sh; 
      ".config/wofi/gopass.launcher.sh".source = ./dotfiles/.config/wofi/gopass.launcher.sh;
      ".config/gopass/stores.local".source = ./dotfiles/.config/gopass/stores.local;  
      # ".config/gtk-4.0/gtk.css".source = ./dotfiles/.config/gtk-4.0/gtk.css; 
      # ".config/gtk-3.0/gtk.css".source = ./dotfiles/.config/gtk-3.0/gtk.css;
      ".config/waybar/style.css".source = ./dotfiles/.config/waybar/style.css;
      ".config/waybar/colors.css".source = ./dotfiles/.config/waybar/colors.css;
      ".config/waybar/config".source = ./dotfiles/.config/waybar/config; 
      ".config/waybar/modules.json".source = ./dotfiles/.config/waybar/modules.json;
      ".config/waybar/ornamental.json".source = ./dotfiles/.config/waybar/ornamental.json;
      ".config/waybar/ornamental.css".source = ./dotfiles/.config/waybar/ornamental.css;
      ".config/waybar/launch_waybar.sh".source = ./dotfiles/.config/waybar/launch_waybar.sh;
      ".config/sway/config".source = ./dotfiles/.config/sway/config;
      ".config/swaylock/config".source = ./dotfiles/.config/swaylock/config;
      ".config/sway/tmux/tmux_reattach.sh".source = ./dotfiles/.config/sway/tmux/tmux_reattach.sh;  

    };




    home.sessionVariables = {
        EDITOR = "nvim";
        VISUAL="nvim";
        GTK_THEME = "Adwaita:dark";
    };

    programs.neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      vimdiffAlias = true;
      plugins = with pkgs.vimPlugins; [
      # nvim-lspconfig
      # nvim-treesitter.withAllGrammars
      # plenary-nvim
      gruvbox-material
      ];
    };

    programs.tmux = {
    enable = true;
    terminal = "tmux-256color";
    historyLimit = 100000;
    prefix = "C-Space";
    mouse = true;
    shell = "${pkgs.zsh}/bin/zsh";
    keyMode = "vi";
    escapeTime = 10;

    plugins = with pkgs.tmuxPlugins; [
      # tmuxPlugins.tokyo-night-tmux
      # tmux-thumbs
      # cpu
      # vim-tmux-navigator
      # better-mouse-mode
      # sensible
      # yank
      # {
      #   plugin = power-theme;
      #   extraConfig = ''
      #      set -g @tmux_power_theme 'gold'
      #   '';
      # }
      # {
      #   plugin = resurrect;
      #   extraConfig = ''
      #     # set -g @resurrect-strategy-nvim 'session'
      #     set -g @resurrect-capture-pane-contents 'on'
      #   '';
      # }
      # {
      #   plugin = continuum;
      #   extraConfig = ''
      #     set -g @continuum-restore 'on'
      #     # set -g @continuum-save-interval '60' # minutes
      #   '';
      # }
    ];


    extraConfig = ''
      # ${pkgs.zsh}
      set -g default-terminal "tmux-256color"
      set -ag terminal-overrides ",xterm-256color:RGB"

      set-window-option -g mode-keys vi

      # Unbinding
      unbind C-b
      unbind %
      unbind '"'
      unbind r
      unbind -T copy-mode-vi MouseDragEnd1Pane # don't exit copy mode when dragging with mouse

      # Bind Keys
      bind-key C-Space send-prefix
      bind | split-window -h 
      bind - split-window -v
      bind r source-file ~/.config/tmux/tmux.conf

      # Resize Pane
      # bind j resize-pane -D 5
      # bind k resize-pane -U 5
      # bind l resize-pane -R 5
      # bind h resize-pane -L 5
      # bind -r m resize-pane -Z

      # bind-key -T copy-mode-vi 'v' send -X begin-selection # start selecting text with "v"
      # bind-key -T copy-mode-vi 'y' send -X copy-selection # copy text with "y"

      # # For Yazi
      # set -g allow-passthrough all
      # set -ga update-environment TERM
      # set -ga update-environment TERM_PROGRAM
    '';
  };



      qt = {
        enable = true;
        platformTheme.name = "qtct";
        style.name = "kvantum";
      };

      xdg.configFile = {
        "Kvantum/kvantum.kvconfig".text = ''
          [General]
          theme=WhiteSur
        '';

        "Kvantum/WhiteSurDark".source = "${pkgs.whitesur-kde}/share/Kvantum/WhiteSur";
      };

    # qt = {
    #   enable = true;
    #   platformTheme.name = "gtk";
    #   style.name = "adwaita-dark";
    # };



    services.gpg-agent = {
      enable = true;
      enableSshSupport = true;
      pinentry.package = pkgs.pinentry-gnome3;
    };


    services.flameshot = {
    enable = true;
    settings.General = {
      showStartupLaunchMessage = false;
      saveLastRegion = true;
    };
  };


    gtk = {
      enable = true;
      # gtk3.extraConfig.gtk-decoration-layout = "menu:";
      # gtk3.bookmarks = [
      #   "file://home/mhr/nixos"
      # ];
      #   theme = {
        #   name = "Arc-Dark";
        #   package = pkgs.arc-theme;
        # };
        # theme = {
        #   package = pkgs.adw-gtk3;
        #   name = "adw-gtk3-dark";
        # };
        # theme = {
        #   name = "Materia-Dark";
        #   package = pkgs.materia-theme;
        # };
        theme = {
          name = "WhiteSur-Dark";
          package = pkgs.whitesur-gtk-theme;
        };
        cursorTheme = {
          package = pkgs.bibata-cursors;
          name = "Bibata-Modern-Ice";
        };
        iconTheme = {
          package = pkgs.whitesur-icon-theme;
          name = "WhiteSur-Dark"; # "WhiteSur-Dark" "WhiteSur-Light"
        };
        # iconTheme = {
        #   package = gruvboxPlus;
        #   name = "Gruvbox-plus"; # "WhiteSur-Dark" "WhiteSur-Light"
        # };
      };


      # Let Home Manager install and manage itself.
      programs.home-manager.enable = true;
    }
