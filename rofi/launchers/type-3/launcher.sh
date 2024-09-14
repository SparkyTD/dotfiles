#!/usr/bin/env bash

RUNNING_PID=$(ps -aux | grep -v grep | grep rofi | grep -v bash | awk '{ if ($11 == "rofi") {print $2} }')
if [ ! -z "$RUNNING_PID" ]; then
    kill -9 "$RUNNING_PID"
    exit 0
fi

## Author : Aditya Shakya (adi1090x)
## Github : @adi1090x
#
## Rofi   : Launcher (Modi Drun, Run, File Browser, Window)
#
## Available Styles
#
## style-1     style-2     style-3     style-4     style-5
## style-6     style-7     style-8     style-9     style-10

dir="$HOME/.config/rofi/launchers/type-3"
theme='style-8'

## Run
rofi \
    -show drun \
    -theme ${dir}/${theme}.rasi
