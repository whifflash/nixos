{ config, pkgs, lib, ... }:

{

	imports = [
    ./ssh.nix
  ];


  home.username = "mhr";             # <-- change if your macOS user differs
  home.homeDirectory = lib.mkForce "/Users/mhr"; # <-- change if needed
  home.stateVersion = "24.11";       # align with your repo

  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    userName = "mhr";
    userEmail = "mhr@c4rb0n.cloud";
    extraConfig.init.defaultBranch = "main";
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
    nil   # Nix LSP
  ];
}
