#!/bin/bash

CONFIG_DIR="$HOME/.config/ags"

trap "killall ags" EXIT

while true; do
    ags | tee "$CONFIG_DIR/ags.log" &
    inotifywait -e create,modify --recursive --include '.*\.(json|ts)$' $CONFIG_DIR
    killall ags 
done
