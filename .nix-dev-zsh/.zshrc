# ---- nix devshell zshrc (generated) ----
export ZSH="/nix/store/lz5cg51f57zg5adc0zbfbya4jqr7jlx7-oh-my-zsh-2025-04-29/share/oh-my-zsh"
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
