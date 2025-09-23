{ ... }:
{
  homebrew = {
    enable = true;
    brews = [ "choose-gui" ];
    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "zap";
    };
  };
}
