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
  ];

  xdg.enable = true;

  xdg.configFile."aerospace/aerospace.toml".text = ''
    start-at-login = true


    [gaps]
      inner.horizontal = 6
      inner.vertical   = 6
      outer.left       = 6
      outer.bottom     = 6
      outer.top        = 6
      outer.right      = 6

    [mode.main.binding]
      # Layout toggles
      alt-slash = "layout tiles horizontal vertical"
      alt-comma = "layout accordion horizontal vertical"

      # Focus movement
      alt-h = "focus left"
      alt-j = "focus down"
      alt-k = "focus up"
      alt-l = "focus right"

      # Move window
      alt-shift-h = "move left"
      alt-shift-j = "move down"
      alt-shift-k = "move up"
      alt-shift-l = "move right"

      # Workspaces
      alt-1 = "workspace 1"
      alt-2 = "workspace 2"
      alt-3 = "workspace 3"
      alt-4 = "workspace 4"
      alt-5 = "workspace 5"
      alt-6 = "workspace 6"
      alt-7 = "workspace 7"
      alt-8 = "workspace 8"
      alt-9 = "workspace 9"

      # Move window to workspace
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

      # Float & fullscreen toggles
      alt-f = "fullscreen"
      alt-t = "layout floating tiling"

      # Scratchpad toggle (show existing or spawn alacritty+tmux)
      alt-i = "exec-and-forget aerospace-scratchpad show alacritty -F window-title='TMuxScratchpad' || alacritty -t 'TMuxScratchpad' -e tmux new-session -A -s scratch"

    # Ensure aerospace’s exec-* sees the right PATH (inherits and extends)
    [exec.env-vars]
        PATH = "${config.home.homeDirectory}/.nix-profile/bin:/etc/profiles/per-user/${config.home.username}/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"


    # Auto-handle the scratchpad window when it appears
    [[on-window-detected]]
    if.app-id = "org.alacritty"
    if.window-title-regex-substring = "TMuxScratchpad"
    run = ["layout floating", "move-node-to-workspace .scratchpad"]

    [workspace-to-monitor-force-assignment]
    ".scratchpad" = ["secondary", "main"]
  '';
}
