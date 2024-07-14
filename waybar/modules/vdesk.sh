#!/bin/bash

desktop_indicator() {
    local total=$1
    local current=$2
    local inactive=" "
    local active=" "

    for ((i=1; i<=$total; i++)); do
        if [ $i -eq $current ]; then
            echo -n "$active"
        else
            echo -n "$inactive"
        fi
    done
    echo
}

last_vdesk="0"
active_vdesk=""
print_indicator() {
    vdesk_state=$(hyprctl printstate)
    active_vdesk=$(echo "$vdesk_state" | grep "Focused: true" -B1 | head -n 1 | cut -d ' ' -f 2 | cut -d ':' -f 1)
    max_vdesk=$(echo "$vdesk_state" | grep "Focused:" | wc -l)
    if (( active_vdesk <= 4 )); then
        max_vdesk=4
    elif (( max_vdesk > 4 )); then
        max_vdesk=$active_vdesk
    fi
    indicator=$(desktop_indicator $max_vdesk $active_vdesk)

    if [ $active_vdesk -ne $last_vdesk ]; then
        echo "{\"text\": \"$indicator\", \"tooltip\": false, \"class\": \"vdesk\" }"
    fi
    last_vdesk=$active_vdesk
}

print_indicator

while read -r line; do
    print_indicator
done < <(socat -u "UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" -)
