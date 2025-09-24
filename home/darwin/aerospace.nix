# home/darwin/aerospace.nix
{
  inputs,
  pkgs,
  config,
  ...
}: {
  home.packages = [
    inputs.aerospace-scratchpad.packages.${pkgs.system}.default
    pkgs.alacritty
    pkgs.tmux
    pkgs.jq
  ];

  xdg.enable = true;

  # Helper that: show/spawn the scratch terminal, find its window id,
  # force tiling, then force fullscreen (no outer gaps) every time.
  xdg.configFile."aerospace/toggle_scratch_full.sh" = {
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      TITLE="TMuxScratchpad"
      BUNDLE="org.alacritty"

      # 1) Show (or spawn) the scratch terminal
      if ! aerospace-scratchpad show alacritty -F window-title="$TITLE"; then
        alacritty -t "$TITLE" -e tmux new-session -A -s scratch &
        # Give the window a moment to appear
        sleep 0.15
      else
        # Still give it a split-second to become focusable/listable
        sleep 0.05
      fi

      # 2) Find the *latest* Alacritty window with our title
      id="$(
        aerospace list-windows --all --app-bundle-id "$BUNDLE" --json \
          | jq -r --arg t "$TITLE" '
              [ .[] | select(."window-title" == $t) ][-1]."window-id"
            '
      )"

      # 3) Force tiling (fullscreen works on tiling windows)
      if [[ -n "${id:-}" && "$id" != "null" ]]; then
        aerospace layout tiling --window-id "$id" || true
        # 4) Re-apply fullscreen without outer gaps
        aerospace fullscreen on --window-id "$id" --no-outer-gaps || true
      fi
    '';
    executable = true;
  };

  xdg.configFile."aerospace/aerospace.toml".text = ''
    start-at-login = true

    [gaps]
      inner.horizontal = 6
      inner.vertical   = 6
      outer.left       = 6
      outer.bottom     = 6
      outer.top        = 6
      outer.right      = 6

    [exec]
      inherit-env-vars = true

    [exec.env-vars]
      PATH = "${config.home.homeDirectory}/.nix-profile/bin:/etc/profiles/per-user/${config.home.username}/bin:/run/current-system/sw/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

    [mode.main.binding]
      # i3-ish movement/layout
      alt-slash = "layout tiles horizontal vertical"
      alt-comma = "layout accordion horizontal vertical"
      alt-h = "focus left"
      alt-j = "focus down"
      alt-k = "focus up"
      alt-l = "focus right"
      alt-shift-h = "move left"
      alt-shift-j = "move down"
      alt-shift-k = "move up"
      alt-shift-l = "move right"
      alt-1 = "workspace 1"
      alt-2 = "workspace 2"
      alt-3 = "workspace 3"
      alt-4 = "workspace 4"
      alt-5 = "workspace 5"
      alt-6 = "workspace 6"
      alt-7 = "workspace 7"
      alt-8 = "workspace 8"
      alt-9 = "workspace 9"
      alt-shift-1 = "move-node-to-workspace 1"
      alt-shift-2 = "move-node-to-workspace 2"
      alt-shift-3 = "move-node-to-workspace 3"
      alt-shift-4 = "move-node-to-workspace 4"
      alt-shift-5 = "move-node-to-workspace 5"
      alt-shift-6 = "move-node-to-workspace 6"
      alt-shift-7 = "move-node-to-workspace 7"
      alt-shift-8 = "move-node-to-workspace 8"
      alt-shift-9 = "move-node-to-workspace 9"
      alt-space = "workspace-back-and-forth"
      alt-f = "fullscreen"
      alt-t = "layout floating tiling"

      # Scratchpad toggle (always ends fullscreen)
      alt-i = "exec-and-forget bash -lc '~/.config/aerospace/toggle_scratch_full.sh'"

    # IMPORTANT: Do not force the scratch terminal to floating here.
  '';
}
