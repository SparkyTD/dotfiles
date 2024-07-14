#!/bin/bash

STATUS_FILE="/tmp/ovpn_status.json"

ICON_CONNECTED=""
ICON_DISCONNECTED=""
ICON_CONNECTING=""

update_indicator() {
    local status_data=$(cat $STATUS_FILE | jq -c)
    local status=$(echo $status_data | jq -r '.status')
    local config=$(echo $status_data | jq -r '.connection')

    local status_text=
    local status_icon=

    if [ "$status" = "connecting" ]; then
        status_text="Connecting..."
        status_icon="$ICON_CONNECTING"
    elif [ "$status" = "connected" ]; then
        status_text="VPN: $config"
        status_icon="$ICON_CONNECTED"
    elif [ "$status" = "disconnecting" ]; then
        status_text="Disconnecting..."
        status_icon="$ICON_CONNECTING"
    elif [ "$status" = "disconnected" ]; then
        status_text="VPN: Disconnected"
        status_icon="$ICON_DISCONNECTED"
    fi

    echo "{\"text\": \"$status_text\", \"tooltip\": \"$status_text\", \"class\": \"vpn\"}"
}

update_indicator

while true; do
    inotifywait -qq -e modify $STATUS_FILE > /dev/null
    update_indicator
done
