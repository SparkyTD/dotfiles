#!/bin/bash

# Take the screenie
IMAGE_PATH=$(grimshot savecopy area)

# Promt user to save
NEW_PATH=$(zenity --file-selection --save --confirm-overwrite --filename=$IMAGE_PATH)

if [ "$IMAGE_PATH" != "$NEW_PATH" ]; then
    mv "$IMAGE_PATH" "$NEW_PATH"
    IMAGE_PATH="$NEW_PATH"
fi

echo "Screenshot saved to '$IMAGE_PATH'!"
