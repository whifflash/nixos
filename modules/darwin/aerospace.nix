# modules/darwin/aerospace.nix
_: {
  homebrew = {
    enable = true;
    taps = ["nikitabobko/tap"];
    casks = ["nikitabobko/tap/aerospace"];
    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "zap";
    };
  };
}
