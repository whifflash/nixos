#!/usr/bin/env bash

# dir="$HOME/.config/rofi/"
# theme='config'

if [ ! -f /tmp/pass.store ]; then
    PASSWORD_STORE_DIR=~/.password-store-personal
else
    PASSWORD_STORE_DIR=$(cat /tmp/pass.store)
fi

PASSWORD_STORE_DIR=$PASSWORD_STORE_DIR gopass ls --flat | \
    wofi -dmenu -p "$PASSWORD_STORE_DIR" | \
    xargs --no-run-if-empty -I {} /usr/bin/env bash -c 'PASSWORD_STORE_DIR='$PASSWORD_STORE_DIR' gopass show --clip "{}"'

    # rofi -theme ${dir}/${theme}.rasi -dmenu -p "$PASSWORD_STORE_DIR" | \
