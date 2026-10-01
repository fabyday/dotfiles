#!/usr/bin/env sh

if [ "$SELECTED" = "true" ]; then
    sketchybar --set "$NAME" \
        icon.color=0xff111827 \
        background.drawing=on \
        background.color=0xffd1d5db
else
    sketchybar --set "$NAME" \
        icon.color=0xff9ca3af \
        background.drawing=on \
        background.color=0x332a2a33
fi
