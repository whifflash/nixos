{ pkgs, ... }:
{
  # The desktop layer — token theming + runtime switcher, the sway/niri/waybar/
  # swaync shell, tmux (resurrect/continuum), gopass (store switcher, browser
  # bridge, SSH askpass) and repo-sync — comes from the nix-desktop flake input
  # via home-manager.sharedModules (flake-modules/nixos). Its knobs live in
  # hosts/<host>/config.toml. This file holds what is specific to this repo.
  imports = [
    ./packages.nix
    ./apps/direnv.nix
    ./apps/firefox
    ./git.nix
    ./ssh.nix
    ./apps/repo-sync-token.nix
    ./apps/herdr.nix
    ./apps/zsh.nix
  ];

  # Managed Chromium (was a bare package in role_workstation) so the shared
  # gopass module can force-install gopassbridge into it.
  programs.chromium.enable = true;

  home = {
    username = "mhr";
    homeDirectory = "/home/mhr";

    stateVersion = "24.11"; # Please read the comment before changing.

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

      withRuby = false;
      withPython3 = false;

      plugins = with pkgs.vimPlugins; [
        # nvim-lspconfig
        # nvim-treesitter.withAllGrammars
        # plenary-nvim
        # gruvbox-material
      ];
    };
  }; # end of programs = {};

  gtk.enable = true;
}
