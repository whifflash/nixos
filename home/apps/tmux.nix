{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkOption mkEnableOption types;
  cfg = config.hm.tmux;
in {
  options.hm.tmux = {
    enable = mkEnableOption "enable my opinionated tmux config";

    terminal = mkOption {
      type = types.str;
      default = "tmux-256color";
      description = "Default tmux terminal type.";
    };

    historyLimit = mkOption {
      type = types.int;
      default = 100000;
      description = "Scrollback lines per pane.";
    };

    shell = mkOption {
      type = types.str;
      default = "${pkgs.zsh}/bin/zsh";
      description = "Shell used when tmux creates panes/windows.";
    };

    mouse = mkOption {
      type = types.bool;
      default = true;
      description = "Enable mouse support.";
    };

    escapeTime = mkOption {
      type = types.int;
      default = 10;
      description = "Escape-time in milliseconds.";
    };
  };

  config = mkIf cfg.enable {
    programs.tmux = {
      enable = true;

      inherit (cfg) terminal historyLimit shell mouse escapeTime;

      prefix = "C-a";
      keyMode = "vi";
      plugins = [];

      extraConfig = ''
        set -g default-terminal "${cfg.terminal}"
        set -ag terminal-overrides ",xterm-256color:RGB"

        set-window-option -g mode-keys vi

        # Unbinding
        unbind C-b
        unbind %
        unbind '"'
        unbind r
        unbind -T copy-mode-vi MouseDragEnd1Pane

        # Bind Keys (Ctrl-A is the prefix)
        bind-key C-a send-prefix
        bind | split-window -h
        bind - split-window -v
        bind c new-window
        bind x kill-window

        bind r source-file ~/.config/tmux/tmux.conf

        # Pane navigation (vim-style)
        bind h select-pane -L
        bind j select-pane -D
        bind k select-pane -U
        bind l select-pane -R


        # Pane resizing (Shift + hjkl)
        bind -r H resize-pane -L 5
        bind -r J resize-pane -D 5
        bind -r K resize-pane -U 5
        bind -r L resize-pane -R 5
      '';
    };
  };
}
