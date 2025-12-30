_: {
  homebrew = {
    enable = true;
    casks = [ "alacritty" ];
    brews = ["choose-gui"];
    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "zap";
    };
  };
}
