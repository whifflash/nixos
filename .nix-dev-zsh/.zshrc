# ---- nix devshell zshrc (generated) ----
export ZSH="/nix/store/s0v5f4acq973z14fqwr676qy3rp8vsl1-oh-my-zsh-2026-02-19/share/oh-my-zsh"
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
