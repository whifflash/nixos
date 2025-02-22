#!/usr/bin/zsh
# Helper-rofi to quickly change the current passsword store

# First displays a static list of stores, relative to $HOME to choose from
# The static list is composed of two lists 
# a machine-specific folder list (in gitignore file of dotfiles repo):

stores="$HOME/.config/gopass/stores.local"

dir="$HOME/.config/rofi/"
theme='config'

# display and choose the folders in which to choose a folder
newstore=$(cat $stores | rofi -dmenu -theme ${dir}/${theme}.rasi)

echo $newstore > /tmp/pass.store