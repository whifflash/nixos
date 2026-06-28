_: {
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;

    # Shell integration is added explicitly because Linux uses a
    # custom XDG zsh configuration while Darwin uses programs.zsh.
    enableZshIntegration = false;
  };
}
