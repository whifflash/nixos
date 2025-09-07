{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}: let
  sw = osConfig.programs.sway.enable or false;
  c = config.hm.theme.colors; # now tokens-backed
  mod = "Mod4";
  term = "${pkgs.alacritty}/bin/alacritty";
  tmux = "${pkgs.tmux}/bin/tmux";

  scratchTitle = "TMuxScratchpad";
in {
  # helper script to spawn-if-missing, then toggle scratchpad
  home.file.".config/sway/scripts/toggle_scratchpad.sh" = lib.mkIf sw {
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail
      term='${term}'
      tmux='${tmux}'
      title='${scratchTitle}'

      if ! pgrep -f "$term.*$title" >/dev/null; then
        "$term" --title "$title" -e "$tmux" new-session -A -s scratch &
        sleep 0.3
      fi

      # Show from scratchpad and fill the output WITHOUT true fullscreen
      swaymsg '[title="'"$title"'"] scratchpad show, sticky enable, move position 0 0, resize set 100 ppt 100 ppt, border none'
    '';
    executable = true;
  };

  wayland.windowManager.sway = lib.mkIf sw {
    enable = true;
    package = pkgs.sway;
    systemd.enable = true;
    xwayland = true;
    wrapperFeatures.gtk = true;

    config = {
      modifier = mod;
      terminal = term;
      menu = "${pkgs.wofi}/bin/wofi --show drun";

      colors = {
        focused = {
          border = c.primary;
          background = c.bg;
          text = c.fg;
          indicator = c.primary;
          childBorder = c.primary;
        };
        focusedInactive = {
          inherit (c) border;
          # border = c.border;
          background = c.bgAlt;
          text = c.muted;
          indicator = c.borderMuted;
          childBorder = c.border;
        };
        unfocused = {
          border = c.borderMuted;
          background = c.bg;
          text = c.muted;
          indicator = c.borderMuted;
          childBorder = c.borderMuted;
        };
        urgent = {
          border = c.error;
          background = c.error;
          text = c.bg;
          indicator = c.error;
          childBorder = c.error;
        };
        placeholder = {
          border = c.borderMuted;
          background = c.surface;
          text = c.fg;
          indicator = c.borderMuted;
          childBorder = c.borderMuted;
        };
      };

      input = {
        "type:touchpad" = {
          tap = "enabled";
          natural_scroll = "enabled";
          middle_emulation = "enabled";
          dwt = "disabled";
          pointer_accel = "0.4";
          accel_profile = "adaptive";
        };
        "type:keyboard" = {
          xkb_layout = "us";
          xkb_options = "caps:ctrl_modifier";
        };
      };

      # use Waybar (your repo ships its files)
      bars = [];
      startup = [
        {
          command = "${config.home.homeDirectory}/.config/waybar/launch_waybar.sh";
          always = true;
        }
        # optional: pre-spawn scratch session (commented; script handles spawn-if-missing)
        # { command = ''${term} --title ${scratchTitle} -e ${tmux} new-session -A -s scratch''; always = false; }
      ];

      # send the scratch terminal to the scratchpad and make it floating/sticky by default
      # (size & position are now handled on toggle to fill the output while keeping bars visible)
      window.commands = [
        {
          criteria = {title = scratchTitle;};
          command = lib.concatStringsSep ", " [
            "floating enable"
            "sticky enable"
            "move to scratchpad"
            "border none"
          ];
        }
      ];

      keybindings =
        # base bindings…
        (lib.mkOptionDefault {
          "${mod}+Return" = "exec ${term}";
          "${mod}+q" = "kill";
          "${mod}+d" = "exec ${pkgs.wofi}/bin/wofi --show drun";

          # toggle scratchpad (spawn if missing) via script — uses your existing chord
          "${mod}+i" = "exec ${config.home.homeDirectory}/.config/sway/scripts/toggle_scratchpad.sh";
          # spawn a named tmux scratch terminal explicitly, if you still want a separate chord
          "${mod}+Shift+Return" = "exec ${term} -t ${scratchTitle} -e ${config.home.homeDirectory}/.config/sway/tmux/tmux_reattach.sh";

          # reload/lock/exit
          "${mod}+Shift+r" = "reload";
          "${mod}+Shift+e" = ''exec sh -lc 'swaynag -t warning -m "Exit Sway?" -b "Logout" "swaymsg exit"'';
          "${mod}+Shift+x" = "exec ${pkgs.swaylock}/bin/swaylock -f";

          # focus / move
          "${mod}+h" = "focus left";
          "${mod}+j" = "focus down";
          "${mod}+k" = "focus up";
          "${mod}+l" = "focus right";
          "${mod}+Shift+h" = "move left";
          "${mod}+Shift+j" = "move down";
          "${mod}+Shift+k" = "move up";
          "${mod}+Shift+l" = "move right";
          "${mod}+space" = "workspace back_and_forth";

          # layout
          "${mod}+v" = "split v";
          "${mod}+b" = "splith";
          "${mod}+f" = "fullscreen toggle";
          # "${mod}+space" = "floating toggle";

          # gopass
          "${mod}+p" = ''exec ${config.home.homeDirectory}/.config/wofi/gopass.launcher.sh'';
          "${mod}+Shift+p" = ''exec ${config.home.homeDirectory}/.config/wofi/gopass.switcher.sh'';
        })
        # workspaces 1–9 (switch & move)
        // lib.listToAttrs (map (n: {
          name = "${mod}+${toString n}";
          value = "workspace number ${toString n}";
        }) (lib.range 1 9))
        // lib.listToAttrs (map (n: {
          name = "${mod}+Shift+${toString n}";
          value = "move container to workspace number ${toString n}";
        }) (lib.range 1 9));
    };
  };
}
