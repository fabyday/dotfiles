#!/usr/bin/env sh
set -eu

CONFIG_DIR="${HOME}/.config/yabai"
STATE_SCRIPT="$CONFIG_DIR/state.sh"

if [ -x "$STATE_SCRIPT" ]; then
    "$STATE_SCRIPT" save >/dev/null 2>&1 || true
fi

yabai --restart-service
sleep 1

if [ -x "$STATE_SCRIPT" ]; then
    "$STATE_SCRIPT" restore >/dev/null 2>&1 || true
fi
