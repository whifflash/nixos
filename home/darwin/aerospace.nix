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

  xdg = {
    enable = true;

    configFile = {
      "aerospace/toggle_scratch.sh" = {
        text = ''
          #!/usr/bin/env bash
          set -euo pipefail

          # Ensure expected PATH when launched by AeroSpace
          export PATH="$HOME/.nix-profile/bin:/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

          TITLE="TMuxScratchpad"
          BUNDLE="org.alacritty"

          # 1) Try to show existing scratch; if missing, spawn it
          if ! aerospace-scratchpad show alacritty -F window-title="$TITLE"; then
            alacritty -t "$TITLE" -e tmux new-session -A -s scratch &
            sleep 0.3
          else
            sleep 0.1
          fi

          # 2) Find the newest matching Alacritty window and focus it
          id="$(
            aerospace list-windows --all --app-bundle-id "$BUNDLE" --json \
              | jq -r --arg t "$TITLE" '[ .[] | select(."window-title" == $t) ][-1]."window-id"'
          )"

          if [ -n "$id" ] && [ "$id" != "null" ]; then
            aerospace focus --window-id "$id" || true
          fi
        '';
        executable = true;
      };

      "aerospace/aerospace.toml".text = ''
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
          alt-space = "workspace-back-and-forth"
          alt-shift-1 = "move-node-to-workspace 1"
          alt-shift-2 = "move-node-to-workspace 2"
          alt-shift-3 = "move-node-to-workspace 3"
          alt-shift-4 = "move-node-to-workspace 4"
          alt-shift-5 = "move-node-to-workspace 5"
          alt-shift-6 = "move-node-to-workspace 6"
          alt-shift-7 = "move-node-to-workspace 7"
          alt-shift-8 = "move-node-to-workspace 8"
          alt-shift-9 = "move-node-to-workspace 9"
          alt-f = "fullscreen"
          alt-t = "layout floating tiling"

          # Scratchpad toggle (simple)
          alt-i = "exec-and-forget bash -lc '~/.config/aerospace/toggle_scratch.sh'"

        # No special rules for the scratchpad window.
      '';
    };
  };
}
