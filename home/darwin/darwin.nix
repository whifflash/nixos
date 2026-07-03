{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ../ssh.nix
    ../apps/direnv.nix
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
      nil # Nix LSP
      vim
    ];
  };

  programs = {
    home-manager.enable = true;

    git = {
      enable = true;
      settings = {
        core.editor = "vim";
        init.defaultBranch = "main";
        user = {
          email = "mhr@c4rb0n.cloud";
          name = "mhr";
        };
      };
    };

    zsh = {
      enable = true;
      dotDir = config.home.homeDirectory;
      # autosuggestions.enable = true;
      syntaxHighlighting.enable = true;

      initContent = ''
        eval "$(direnv hook zsh)"
      '';

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
