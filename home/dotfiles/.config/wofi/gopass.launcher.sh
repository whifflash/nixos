#!/usr/bin/env bash

if [ ! -f /tmp/pass.store ]; then
  PASSWORD_STORE_DIR=~/.password-store-personal
else
  PASSWORD_STORE_DIR=$(cat /tmp/pass.store)
fi

echo $PASSWORD_STORE_DIR

PASSWORD_STORE_DIR=$PASSWORD_STORE_DIR gopass ls --flat |
  wofi --dmenu --matching=fuzzy --insensitive -p "$PASSWORD_STORE_DIR" |
  xargs --no-run-if-empty -I {} /usr/bin/env bash -c 'PASSWORD_STORE_DIR='$PASSWORD_STORE_DIR' gopass show --clip "{}"'
