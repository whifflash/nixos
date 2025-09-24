{pkgs, ...}: {
  programs.tmux = {
    enable = true;
    package = pkgs.tmux;

    terminal = "tmux-256color";
    historyLimit = 100000;
    shell = "${pkgs.zsh}/bin/zsh";
    mouse = true;
    escapeTime = 10;

    prefix = "C-a";
    keyMode = "vi";
    plugins = [];

    extraConfig = ''
         # Truecolor
         set -g default-terminal "tmux-256color"
         set -ag terminal-overrides ",xterm-256color:RGB,*:Tc"

         set -g status-keys vi
         set -g mode-keys vi

         # Unbind defaults
         unbind C-b
         unbind %
         unbind '"'
         unbind r
         unbind x

         # Prefix-based (Ctrl-a)
         bind-key C-a send-prefix
         bind '|' split-window -h
         bind '-' split-window -v
         bind c new-window
         bind x kill-pane
      # bind x confirm-before -p "kill-pane #P? (y/n)" kill-pane
         bind r source-file ~/.config/tmux/tmux.conf

         # Pane nav (vim)
         bind h select-pane -Lß
         bind j select-pane -D
         bind k select-pane -U
         bind l select-pane -R

         # Resize (Shift+hjkl)
         bind -r H resize-pane -L 5
         bind -r J resize-pane -D 5
         bind -r K resize-pane -U 5
         bind -r L resize-pane -R 5

         # --- macOS clipboard integration ---
         # Use system clipboard when copying in copy-mode (pbcopy)
         set -g set-clipboard on

         # Copy selection to clipboard with 'y' or Enter in copy-mode-vi
         bind -T copy-mode-vi y     send-keys -X copy-pipe-and-cancel "pbcopy"
         bind -T copy-mode-vi Enter send-keys -X copy-pipe-and-cancel "pbcopy"

         # Also copy on mouse selection end in copy-mode
         bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "pbcopy"

         # Paste from macOS clipboard without prefix: Alt+v
         bind -n M-v run-shell "tmux set-buffer -- \"$(pbpaste)\"; tmux paste-buffer"

         # --- No-prefix Alt (Option) movement/resize (works with Alacritty option_as_alt) ---
         bind -n M-h select-pane -L
         bind -n M-j select-pane -D
         bind -n M-k select-pane -U
         bind -n M-l select-pane -R

         bind -n M-H resize-pane -L 5
         bind -n M-J resize-pane -D 5
         bind -n M-K resize-pane -U 5
         bind -n M-L resize-pane -R 5
    '';
  };
}
