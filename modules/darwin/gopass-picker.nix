{ config, pkgs, lib, ... }:

{
  # global hotkey daemon (built into nix-darwin)
  services.skhd.enable = true;

  # Hotkeys:
  #  - ⌘P: run the picker with current/auto store
  #  - ⇧⌘P: open the dynamic store switcher (writes /tmp/pass.store)
  services.skhd.skhdConfig = ''
    cmd - p : /bin/zsh -lc "$HOME/.local/bin/gopass-launcher"
    shift + cmd - p : /bin/zsh -lc "$HOME/.local/bin/gopass-switcher"
  '';
}