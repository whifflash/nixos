# modules/darwin/sublime-brew.nix
{ ... }:
{
  homebrew = {
    enable = true;
    casks = [
      "sublime-text"
    ];
  };
}
