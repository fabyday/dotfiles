#!/usr/bin/env sh
set -eu

STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/sketchybar"
PID_FILE="$STATE_DIR/skhd-pid"
GUARD_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/yabai/skhd-focus-guard.state"
MODE_SCRIPT="$HOME/.config/sketchybar/lib/skhd_mode.sh"
MODE_FILE="$STATE_DIR/skhd-mode"
SKHD_CONFIG="$HOME/.config/skhd/.skhdrc"

mkdir -p "$STATE_DIR"
pid="$(launchctl list 2>/dev/null |
    awk '$3 == "com.koekeishiya.skhd" && $1 ~ /^[0-9]+$/ { print $1; exit }')"
previous="$(cat "$PID_FILE" 2>/dev/null || true)"
config_changed=false
if [ -f "$SKHD_CONFIG" ]; then
    if [ ! -f "$MODE_FILE" ] || [ -n "$(find -L "$SKHD_CONFIG" -newer "$MODE_FILE" -print -quit 2>/dev/null)" ]; then
        config_changed=true
    fi
fi
[ "$pid" = "$previous" ] && [ "$config_changed" = false ] && exit 0

if [ -n "$pid" ]; then
    "$MODE_SCRIPT" normal
    printf '%s\n' "$pid" > "$PID_FILE"
elif [ "$(cat "$GUARD_FILE" 2>/dev/null || true)" = "paused" ]; then
    "$MODE_SCRIPT" paused
    printf 'paused\n' > "$PID_FILE"
else
    "$MODE_SCRIPT" stopped
    printf 'stopped\n' > "$PID_FILE"
fi
