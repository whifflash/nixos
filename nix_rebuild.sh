#!/usr/bin/env bash
set -euo pipefail

# Resolve this script’s directory as the flake root
FLAKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TARGET="clio-vm" # or "clio" on bare metal

echo "Rebuilding ${TARGET} from ${FLAKE_DIR} ..."
# Use an absolute path-based flake reference; keep env under sudo
sudo -E nixos-rebuild switch --flake "path:${FLAKE_DIR}#${TARGET}"

#!/usr/bin/env bash

# sudo nixos-rebuild switch --flake .#$(hostname)
#sudo nixos-rebuild switch --flake .#$(hostname) --show-trace
#pkill -SIGUSR2 waybar
#systemctl --user restart waybar
