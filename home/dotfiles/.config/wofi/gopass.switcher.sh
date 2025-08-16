#!/usr/bin/env bash
# Helper-rofi to quickly change the current passsword store

# First displays a static list of stores, relative to $HOME to choose from
# The static list is composed of two lists
# a machine-specific folder list (in gitignore file of dotfiles repo):

stores="$HOME/.config/gopass/stores.local"

# display and choose the folders in which to choose a folder
newstore=$(cat $stores | wofi -dmenu)

echo $newstore >/tmp/pass.store
