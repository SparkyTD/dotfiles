#!/bin/bash

STATUS_FILE="/tmp/ovpn_status.json"

status_notify() {
    local status="$1"
    local conn_name="$2"

    echo "{\"status\": \"$status\", \"connection\": \"$conn_name\"}" > $STATUS_FILE
}

ovpn_disconnect() {
    local connection="$1"

    echo "Disconnecting $connection..."
    status_notify "disconnecting" "$connection"
    openvpn3 session-manage -c $connection --disconnect
    status_notify "disconnected" "$connection"
    echo "Disconnected $connection"
}

ovpn_connect() {
    local connection=$(
        openvpn3 configs-list --json \
            | jq -r 'to_entries[] | .value.name' \
            | rofi -dmenu -p "OVPN"
    )

    if [ -n "$connection" ]; then
        status_notify "connecting" "$connection"
        openvpn3 session-start -c $connection
        status_notify "connected" "$connection"
    fi
}

ovpn_session=$(openvpn3 sessions-list)
current_connection=$(openvpn3 sessions-list | grep -oP 'Config name: \K.*')
if [ -n "$current_connection" ]; then
    ovpn_disconnect $current_connection
else
    ovpn_connect
fi

