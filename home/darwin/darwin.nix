{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ../ssh.nix
    ../apps/sublime.nix
    ./gopass.nix
    ./aerospace.nix
    ./tmux.nix
    ./alacritty.nix
  ];

  home = {
    username = "mhr";
    homeDirectory = lib.mkForce "/Users/mhr";
    stateVersion = "24.11";

    sessionVariables = {
      EDITOR = "vim";
      VISUAL = "vim";
      GIT_EDITOR = "vim";
    };

    packages = with pkgs; [
      starship
      direnv
      nil # Nix LSP
      vim
    ];
  };

  programs = {
    home-manager.enable = true;

    git = {
      enable = true;
      userName = "mhr";
      userEmail = "mhr@c4rb0n.cloud";
      extraConfig.init.defaultBranch = "main";
      extraConfig.core.editor = "vim";
    };

    zsh = {
      enable = true;
      # autosuggestions.enable = true;
      syntaxHighlighting.enable = true;
      shellAliases = {
        ll = "ls -alh";
        gs = "git status";
        gd = "git diff";
      };
    };

    starship = {
      enable = true;
      enableZshIntegration = true;
    };
  };
}
