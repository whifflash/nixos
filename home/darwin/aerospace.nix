# home/darwin/aerospace.nix
{
  inputs,
  lib,
  pkgs,
  config,
  ...
}: {
  home.packages = [
    inputs.aerospace-scratchpad.packages.${pkgs.stdenv.hostPlatform.system}.default
    pkgs.alacritty
    pkgs.jq
  ];

  xdg = {
    enable = true;

    configFile = {
      "aerospace/toggle_scratch.sh" = {
        text = ''
          #!/usr/bin/env bash
          set -euo pipefail

          export PATH="$HOME/.nix-profile/bin:/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

          HERDR="${lib.getExe inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default}"
          TITLE="HerdrScratchpad"
          SCRATCH_WORKSPACE=".scratchpad"
          STATE_DIR="$HOME/.local/state/aerospace"
          LOG="$STATE_DIR/scratchpad.log"

          mkdir -p "$STATE_DIR"
          exec >>"$LOG" 2>&1

          log() {
            printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
          }

          matching_window_id() {
            # Match only the fixed scratchpad title so normal Alacritty windows
            # are never mistaken for the scratchpad.
            aerospace list-windows --monitor all --json \
              | jq -r \
                  --arg title "$TITLE" \
                  --arg scratch_workspace "$SCRATCH_WORKSPACE" '
                    [
                      .[]
                      | select(."window-title" == $title)
                    ][-1]."window-id" // empty
                  '
          }

          window_is_on_focused_workspace() {
            local id="$1"

            aerospace list-windows --workspace focused --json \
              | jq -e --arg id "$id" '
                  any(.[]; (."window-id" | tostring) == $id)
                ' >/dev/null
          }

          wait_for_window_id() {
            local id=""

            for _ in $(seq 1 80); do
              id="$(matching_window_id)"

              if [ -n "$id" ]; then
                printf '%s\n' "$id"
                return 0
              fi

              sleep 0.1
            done

            return 1
          }

          current_workspace() {
            aerospace list-workspaces --focused | head -n 1
          }

          show_window() {
            local id="$1"
            local workspace="$2"

            log "show window_id=$id target_workspace=$workspace"
            aerospace move-node-to-workspace --window-id "$id" --focus-follows-window "$workspace"
            aerospace layout --window-id "$id" floating || true
            aerospace focus --window-id "$id" || true
            aerospace fullscreen on || aerospace fullscreen || true
            aerospace move-mouse window-lazy-center || aerospace move-mouse monitor-lazy-center || true
          }

          hide_window() {
            local id="$1"

            log "hide window_id=$id scratch_workspace=$SCRATCH_WORKSPACE"
            aerospace move-node-to-workspace --window-id "$id" "$SCRATCH_WORKSPACE"
          }

          main() {
            local target_workspace
            local id

            target_workspace="$(current_workspace)"
            id="$(matching_window_id)"

            log "toggle target_workspace=$target_workspace window_id=''${id:-<none>}"

            if [ -n "$id" ]; then
              if window_is_on_focused_workspace "$id"; then
                hide_window "$id"
              else
                show_window "$id" "$target_workspace"
              fi

              return 0
            fi

            log "launching new $TITLE terminal"
            alacritty \
              --title "$TITLE" \
              --option window.dynamic_title=false \
              -e env HERDR_SESSION=scratch "$HERDR" >/dev/null 2>&1 &
            id="$(wait_for_window_id)"
            show_window "$id" "$target_workspace"
          }

          main "$@"
        '';
        executable = true;
      };

      "aerospace/aerospace.toml".text = ''
        # Keep this file compatible with the AeroSpace version installed by Homebrew.
        # Older releases reject newer top-level keys such as `config-version` and
        # `auto-reload-config`, so the declarative config intentionally only uses
        # keys accepted by the currently packaged version.
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
          alt-w = "layout h_accordion"
          alt-h = "focus --boundaries-action wrap-around-the-workspace left"
          alt-j = "focus down"
          alt-k = "focus up"
          alt-l = "focus --boundaries-action wrap-around-the-workspace right"
          alt-tab = "focus-back-and-forth"
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

          # Floating Herdr scratchpad terminal. The script logs to
          # ~/.local/state/aerospace/scratchpad.log for troubleshooting.
          alt-i = "exec-and-forget ${config.home.homeDirectory}/.config/aerospace/toggle_scratch.sh"

        # The scratchpad script keeps its hidden terminal on this internal workspace.
        # There is intentionally no keybinding to switch to it directly.
      '';
    };
  };
}
