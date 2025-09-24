# home/darwin/alacritty.nix
{...}: {
  programs.alacritty = {
    enable = true;
    settings = {
      # Add only what we need; keep the rest of your Alacritty config as-is
      keyboard = {
        bindings = [
          # Option+vim arrows -> send ESC-prefixed letters (Meta-h/j/k/l)
          {
            key = "H";
            mods = "Alt";
            chars = "\\u001bh";
          }
          {
            key = "J";
            mods = "Alt";
            chars = "\\u001bj";
          }
          {
            key = "K";
            mods = "Alt";
            chars = "\\u001bk";
          }
          {
            key = "L";
            mods = "Alt";
            chars = "\\u001bl";
          }

          # Option+Shift+vim arrows -> Meta on uppercase (for resize)
          {
            key = "H";
            mods = "Alt|Shift";
            chars = "\\u001bH";
          }
          {
            key = "J";
            mods = "Alt|Shift";
            chars = "\\u001bJ";
          }
          {
            key = "K";
            mods = "Alt|Shift";
            chars = "\\u001bK";
          }
          {
            key = "L";
            mods = "Alt|Shift";
            chars = "\\u001bL";
          }
        ];
      };
    };
  };
}
