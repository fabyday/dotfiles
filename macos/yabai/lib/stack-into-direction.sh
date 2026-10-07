#!/usr/bin/env sh
set -eu

direction="${1:-}"

case "$direction" in
    west|south|north|east)
        ;;
    *)
        printf 'usage: %s west|south|north|east\n' "$0" >&2
        exit 2
        ;;
esac

current_json="$(yabai -m query --windows --window 2>/dev/null || true)"
[ -n "$current_json" ] || exit 0

current_id="$(printf '%s\n' "$current_json" | jq -r '.id // empty')"
[ -n "$current_id" ] || exit 0

target_json="$(yabai -m query --windows --window "$direction" 2>/dev/null || true)"
target_id="$(printf '%s\n' "$target_json" | jq -r '.id // empty' 2>/dev/null || true)"

if [ -n "$target_id" ] && [ "$target_id" != "$current_id" ]; then
    # Stack the focused window on the directional neighbor.
    yabai -m window "$target_id" --stack "$current_id" >/dev/null 2>&1 || exit 1
    yabai -m window --focus "$current_id" >/dev/null 2>&1 || true
    exit 0
fi

printf 'No window to stack toward %s\n' "$direction" >&2
exit 1
