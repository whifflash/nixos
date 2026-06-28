# ---- nix devshell zshrc (generated) ----
export ZSH="/nix/store/bm7sbsf7fs8rnm9jy0l6zjpkjnax3q7b-oh-my-zsh-2026-02-19/share/oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git)   # <- enables ga, gco, gst, etc.

# Make sure the dev shell's tools are first on PATH
# (Nix already sets PATH, this is just a friendly reminder spot.)
# export PATH="$PATH"

# Don’t let omz auto-update in ephemeral shells
DISABLE_AUTO_UPDATE="true"
DISABLE_UPDATE_PROMPT="true"

source "$ZSH/oh-my-zsh.sh"
# ---- end generated ----
