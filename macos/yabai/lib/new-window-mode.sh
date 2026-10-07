#!/usr/bin/env sh
set -eu

STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/yabai"
MODE_FILE="$STATE_DIR/new-window-mode"

read_mode() {
    mode="$(cat "$MODE_FILE" 2>/dev/null || true)"
    case "$mode" in
        stack|bsp) printf '%s\n' "$mode" ;;
        *) printf 'stack\n' ;;
    esac
}

case "${1:-}" in
    get)
        read_mode
        ;;
    set)
        case "${2:-}" in
            stack|bsp) mode="$2" ;;
            *) printf 'usage: %s set stack|bsp\n' "$0" >&2; exit 2 ;;
        esac
        mkdir -p "$STATE_DIR"
        printf '%s\n' "$mode" > "$MODE_FILE"
        "$0" sync
        ;;
    sync)
        mode="$(read_mode)"
        if command -v sketchybar >/dev/null 2>&1; then
            case "$mode" in
                stack) color=0xff86efac; background=0x55166534 ;;
                bsp) color=0xff93c5fd; background=0x553b82f6 ;;
            esac
            sketchybar --set new_window.mode \
                label="$(printf '%s' "$mode" | tr '[:lower:]' '[:upper:]')" \
                icon.color="$color" label.color="$color" \
                background.color="$background" >/dev/null 2>&1 || true
        fi
        ;;
    *)
        printf 'usage: %s get|set stack|set bsp|sync\n' "$0" >&2
        exit 2
        ;;
esac
