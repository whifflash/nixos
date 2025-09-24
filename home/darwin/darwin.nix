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

  home.username = "mhr";
  home.homeDirectory = lib.mkForce "/Users/mhr";
  home.stateVersion = "24.11";

  programs.home-manager.enable = true;

  home.sessionVariables = {
    EDITOR = "vim";
    VISUAL = "vim";
    GIT_EDITOR = "vim";
  };

  programs.git = {
    enable = true;
    userName = "mhr";
    userEmail = "mhr@c4rb0n.cloud";
    extraConfig.init.defaultBranch = "main";
    extraConfig.core.editor = "vim";
  };

  programs.zsh = {
    enable = true;
    # autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      ll = "ls -alh";
      gs = "git status";
      gd = "git diff";
    };
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };

  home.packages = with pkgs; [
    starship
    direnv
    nil # Nix LSP
    vim
  ];
}
