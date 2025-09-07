#!/usr/bin/env bash

# sudo nixos-rebuild switch --flake .#$(hostname)
sudo nixos-rebuild switch --flake .#$(hostname) --show-trace
pkill -SIGUSR2 waybar
systemctl --user restart waybar
