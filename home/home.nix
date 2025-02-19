{ config, pkgs, ... }:

let 
  gruvboxPlus = import ./themes/icons/gruvbox-plus.nix { inherit pkgs; };
in
{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "mhr";
  home.homeDirectory = "/home/mhr";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "24.05"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = [
  # # Adds the 'hello' command to your environment. It prints a friendly
  # # "Hello, world!" when run.
  # # pkgs.hello
  pkgs.whitesur-gtk-theme
  pkgs.whitesur-cursors
  pkgs.whitesur-icon-theme

  # # It is sometimes useful to fine-tune packages, for example, by applying
  # # overrides. You can do that directly here, just don't forget the
  # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
  # # fonts?
  # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

  # # You can also create simple shell scripts directly inside your
  # # configuration. For example, this adds a command 'my-hello' to your
  # # environment:
  # (pkgs.writeShellScriptBin "my-hello" ''
  #   echo "Hello, ${config.home.username}!"
  # '')
  ];

  # wayland.windowManager.hyprland.enable = true; # enable Hyprland
  # wayland.windowManager.hyprland.settings = {
    #   "$mod" = "SUPER";
    #   bind =
    #     [
    #       "$mod, F, exec, firefox"
    #       ", Print, exec, grimblast copy area"
    #     ]
    #     ++ (
    #       # workspaces
    #       # binds $mod + [shift +] {1..9} to [move to] workspace {1..9}
    #       builtins.concatLists (builtins.genList (i:
    #           let ws = i + 1;
    #           in [
    #             "$mod, code:1${toString i}, workspace, ${toString ws}"
    #             "$mod SHIFT, code:1${toString i}, movetoworkspace, ${toString ws}"
    #           ]
    #         )
    #         9)
    #     );
    # };

    # Home Manager is pretty good at managing dotfiles. The primary way to manage
    # plain files is through 'home.file'.
    home.file = {
      # ".config/hypr/hyprland.conf".source = ./dotfiles/.config/hypr/hyprland.conf;
      ".config/waybar/style.css".source = ./dotfiles/.config/waybar/style.css;
      ".config/waybar/config.jsonc".source = ./dotfiles/.config/waybar/config.jsonc; 
      # ".config/gtk-3.0/gtk.css".source = ./dotfiles/.config/gtk-4.0/gtk.css; 
      # ".config/gtk-3.0/gtk.css".source = ./dotfiles/.config/gtk-3.0/gtk.css;
    };


    # Include the following for git

    # There is also a possibility to configure identity based on filesystem tree path.

    # e.g. having in ~/.gitconfig the following fragment

    # [includeIf "gitdir:~/dev/private/"]
    #     path = ~/.gitconfig.private

    # and in ~/.gitconfig.private

    # [user]
    #     name = Real Name 
    #     email = username@whatever.com

    # will override default identity properties in global config when a project is placed under a subtree of ~/dev/private/.

    programs.git = {
      enable = true;
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
      # mini-nvim
      # (fromGitHub "HEAD" "elihunter173/dirbuf.nvim")
      ];
    };

    qt = {
      enable = true;
      platformTheme.name = "gtk";
      style.name = "adwaita-dark";
    };

    gtk = {
      enable = true;
      gtk3.extraConfig.gtk-decoration-layout = "menu:";
      #   theme = {
        #   name = "Arc-Dark";
        #   package = pkgs.arc-theme;
        # };
        theme = {
          name = "adw-gtk3-dark";
          package = pkgs.adw-gtk3;
        };
        # theme = {
        #   name = "Materia-Dark";
        #   package = pkgs.materia-theme;
        # };
        # theme = {
        #   name = "whitesur-gtk-theme";
        #   package = pkgs.whitesur-gtk-theme;
        # };
        cursorTheme = {
          package = pkgs.bibata-cursors;
          name = "Bibata-Modern-Ice";
        };
        iconTheme = {
          package = gruvboxPlus;
          name = "Gruvbox-plus"; # "WhiteSur-Dark" "WhiteSur-Light"
        };
      };


      # programs.git.includes
      #   List of configuration files to include.

      #   Type: list of (submodule)

      #   Default: [ ]

      #   Example:

      #       [
      #         { path = "~/path/to/config.inc"; }
      #         {
       #           path = "~/path/to/conditional.inc";
       #           condition = "gitdir:~/src/dir";
       #         }
       #       ]

       #   Declared by:
       #       <home-manager/modules/programs/git.nix>

       # Home Manager can also manage your environment variables through
       # 'home.sessionVariables'. These will be explicitly sourced when using a
       # shell provided by Home Manager. If you don't want to manage your shell
       # through Home Manager then you have to manually source 'hm-session-vars.sh'
       # located at either
       #
       #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
       #
       # or
       #
       #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
       #
       # or
       #
       #  /etc/profiles/per-user/mhr/etc/profile.d/hm-session-vars.sh
       #
       home.sessionVariables = {
        EDITOR = "nvim";
      };

      # Let Home Manager install and manage itself.
      # programs.home-manager.enable = true;
    }
