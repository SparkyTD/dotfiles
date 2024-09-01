#!/bin/bash

# Function to get the PID of /usr/bin/ags
get_ags_pid() {
    pgrep -f "/usr/bin/ags"
}

# Function to relay stdout of a process
relay_stdout() {
    local pid=$1
    local stdout_path="/proc/$pid/fd/1"

    if [ ! -e "$stdout_path" ]; then
        echo "Error: Process with PID $pid does not exist or stdout is not accessible."
        return 1
    fi

    if [ ! -r "$stdout_path" ]; then
        echo "Error: No permission to read stdout of process $pid."
        return 1
    fi

    echo "Relaying stdout of process $pid (/usr/bin/ags)"
    tail -f "$stdout_path" &
    local tail_pid=$!

    # Monitor the ags process
    while kill -0 $pid 2>/dev/null; do
        sleep 1
    done

    # If we reach here, the ags process has died
    kill $tail_pid 2>/dev/null  # Stop the tail process
    echo "Process /usr/bin/ags (PID $pid) has terminated."
}

# Main loop
while true; do
    echo "Waiting for /usr/bin/ags to start..."
    
    while true; do
        pid=$(get_ags_pid)
        if [ -n "$pid" ]; then
            break
        fi
        sleep 1
    done

    echo "Found /usr/bin/ags with PID: $pid"
    relay_stdout $pid

    echo "Restarting monitoring process..."
    sleep 1  # Brief pause before restarting
done
