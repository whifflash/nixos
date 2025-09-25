# modules/darwin/sublime-brew.nix
_: {
  homebrew = {
    enable = true;
    casks = [
      "sublime-text"
    ];
  };
}
