{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}: let
  sw = osConfig.programs.sway.enable or false;
  mod = "Mod4";
  term = "${pkgs.alacritty}/bin/alacritty";
  tmux = "${pkgs.tmux}/bin/tmux";

  scratchTitle = "TMuxScratchpad";
  scratchSpawn = ''
    ${term} --title ${scratchTitle} -e ${tmux} new-session -A -s scratch
  '';
  toggleScratch = ''
    sh -lc 'pgrep -f "${term}.*${scratchTitle}" >/dev/null \
      || (${scratchSpawn} & sleep 0.3); swaymsg scratchpad show'
  '';

  terminalNamed = ''alacritty -t 'TMUXScratchpad' -e /home/mhr/.config/sway/tmux/tmux_reattach.sh'';
in {
  wayland.windowManager.sway = lib.mkIf sw {
    enable = true; # okay to repeat; it’s the same option
    package = pkgs.sway;
    systemd.enable = true;
    xwayland = true;
    wrapperFeatures.gtk = true;

    config = {
      modifier = mod;
      terminal = term;
      menu = "${pkgs.wofi}/bin/wofi --show drun";

      # Touchpad + keyboard
      input = {
        "type:touchpad" = {
          tap = "enabled";
          natural_scroll = "enabled";
          middle_emulation = "enabled";
          dwt = "disabled";
          pointer_accel = "0.4"; # adjust to taste
          accel_profile = "adaptive"; # or "flat"
        };
        "type:keyboard" = {
          xkb_layout = "us";
          xkb_options = "caps:escape";
        };
      };

      # Use Waybar (you already keep its files in the repo)
      bars = [];
      startup = [
        {
          command = "${config.home.homeDirectory}/.config/waybar/launch_waybar.sh";
          always = true;
        }
        {
          command = scratchSpawn;
          always = false;
        }
      ];

      # Float & center the scratch terminal and keep it in the scratchpad
      window.commands = [
        {
          criteria.title = scratchTitle;
          command = lib.concatStringsSep ", " [
            "floating enable"
            "sticky enable"
            "move to scratchpad"
            "resize set width 1200 px height 700 px"
            "move position center"
            "border pixel 2"
          ];
        }
        {
          criteria = {title = "TMUXScratchpad";};
          # do it in-order so resize happens after it’s floating
          command = "floating enable, resize set 400 400, move to scratchpad";
        }
      ];

      #       set $left h
      # set $down j
      # set $up k
      # set $right l

      # bindsym $mod+minus scratchpad show
      # bindsym $mod+p exec /home/mhr/.config/wofi/gopass.launcher.sh
      # bindsym $mod+Shift+p exec /home/mhr/.config/wofi/gopass.switcher.sh

      keybindings = lib.mkOptionDefault ({
          "${mod}+Return" = "exec ${term}";
          "${mod}+q" = "kill";
          "${mod}+d" = "exec ${pkgs.wofi}/bin/wofi --show drun";
          # "${mod}+i" = "exec ${toggleScratch}";
          "${mod}+i" = ''[title="TMUXScratchpad"] scratchpad show'';
          "${mod}+Shift+r" = "reload";
          "${mod}+Shift+e" = ''exec sh -lc 'swaynag -t warning -m "Exit Sway?" -b "Logout" "swaymsg exit"'';
          "${mod}+Shift+x" = "exec ${pkgs.swaylock}/bin/swaylock -f";

          "${mod}+Shift+Return" = "exec ${terminalNamed}";

          # focus
          "${mod}+h" = "focus left";
          "${mod}+j" = "focus down";
          "${mod}+k" = "focus up";
          "${mod}+l" = "focus right";
          # move
          "${mod}+Shift+h" = "move left";
          "${mod}+Shift+j" = "move down";
          "${mod}+Shift+k" = "move up";
          "${mod}+Shift+l" = "move right";
          # layout
          "${mod}+v" = "split v";
          "${mod}+b" = "splith";
          "${mod}+f" = "fullscreen toggle";
          "${mod}+space" = "floating toggle";
          # gopass
          "${mod}+p" = ''exec /home/mhr/.config/wofi/gopass.launcher.sh'';
          "${mod}+Shift+p" = ''exec /home/mhr/.config/wofi/gopass.switcher.sh'';
        }
        # workspaces 1–9 (switch & move)
        // lib.listToAttrs (map (n: {
          name = "${mod}+${toString n}";
          value = "workspace number ${toString n}";
        }) (lib.range 1 9))
        // lib.listToAttrs (map (n: {
          name = "${mod}+Shift+${toString n}";
          value = "move container to workspace number ${toString n}";
        }) (lib.range 1 9)));
    };
  };
}
