#!/usr/bin/env sh
set -eu

STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/yabai"
mkdir -p "$STATE_DIR"

query_window() {
    yabai -m query --windows --window "$1" 2>/dev/null || true
}

focused_window_for_space() {
    display="$1"
    space="$2"
    yabai -m query --windows 2>/dev/null |
        jq -r --argjson display "$display" --argjson space "$space" '
            map(select(.display == $display and .space == $space and ."has-focus" == true)) |
            first |
            .id // empty
        '
}

save_focus() {
    window_id="${YABAI_WINDOW_ID:-}"

    if [ -z "$window_id" ]; then
        window_id="$(yabai -m query --windows --window 2>/dev/null | jq -r '.id // empty')"
    fi

    [ -n "$window_id" ] || exit 0

    window_json="$(query_window "$window_id")"
    [ -n "$window_json" ] || exit 0

    display="$(printf '%s\n' "$window_json" | jq -r '.display // empty')"
    space="$(printf '%s\n' "$window_json" | jq -r '.space // empty')"
    [ -n "$display" ] || exit 0
    [ -n "$space" ] || exit 0

    current_file="$STATE_DIR/focused-window-display-$display-space-$space"
    previous_file="$STATE_DIR/previous-window-display-$display-space-$space"
    old_window=""

    if [ -f "$current_file" ]; then
        old_window="$(cat "$current_file")"
    fi

    if [ -n "$old_window" ] && [ "$old_window" != "$window_id" ]; then
        printf '%s\n' "$old_window" > "$previous_file"
    fi

    printf '%s\n' "$window_id" > "$current_file"
}

stack_new_window() {
    new_window="${YABAI_WINDOW_ID:-}"
    [ -n "$new_window" ] || exit 0

    window_json="$(yabai -m query --windows --window "$new_window" 2>/dev/null || true)"
    [ -n "$window_json" ] || exit 0

    is_floating="$(printf '%s' "$window_json" | jq -r '."is-floating"')"
    can_move="$(printf '%s' "$window_json" | jq -r '."can-move"')"
    is_minimized="$(printf '%s' "$window_json" | jq -r '."is-minimized"')"
    is_hidden="$(printf '%s' "$window_json" | jq -r '."is-hidden"')"
    display="$(printf '%s' "$window_json" | jq -r '.display // empty')"
    space="$(printf '%s' "$window_json" | jq -r '.space // empty')"

    [ "$is_floating" = "false" ] || exit 0
    [ "$can_move" = "true" ] || exit 0
    [ "$is_minimized" = "false" ] || exit 0
    [ "$is_hidden" = "false" ] || exit 0
    [ -n "$display" ] || exit 0
    [ -n "$space" ] || exit 0

    previous_file="$STATE_DIR/previous-window-display-$display-space-$space"
    current_file="$STATE_DIR/focused-window-display-$display-space-$space"
    anchor=""

    if [ -f "$previous_file" ]; then
        anchor="$(cat "$previous_file")"
    fi

    if [ -z "$anchor" ] && [ -f "$current_file" ]; then
        anchor="$(cat "$current_file")"
    fi

    if [ -z "$anchor" ] || [ "$anchor" = "$new_window" ]; then
        anchor="$(focused_window_for_space "$display" "$space")"
    fi

    [ -n "$anchor" ] || exit 0
    [ "$anchor" != "$new_window" ] || exit 0

    anchor_json="$(query_window "$anchor")"
    [ -n "$anchor_json" ] || exit 0

    anchor_display="$(printf '%s\n' "$anchor_json" | jq -r '.display // empty')"
    anchor_space="$(printf '%s\n' "$anchor_json" | jq -r '.space // empty')"
    anchor_floating="$(printf '%s\n' "$anchor_json" | jq -r '."is-floating"')"
    anchor_minimized="$(printf '%s\n' "$anchor_json" | jq -r '."is-minimized"')"
    anchor_hidden="$(printf '%s\n' "$anchor_json" | jq -r '."is-hidden"')"

    [ "$anchor_display" = "$display" ] || exit 0
    [ "$anchor_space" = "$space" ] || exit 0
    [ "$anchor_floating" = "false" ] || exit 0
    [ "$anchor_minimized" = "false" ] || exit 0
    [ "$anchor_hidden" = "false" ] || exit 0

    if yabai -m query --windows --window "$anchor" >/dev/null 2>&1; then
        yabai -m window "$anchor" --stack "$new_window" >/dev/null 2>&1 || true
    fi
}

case "${1:-}" in
    save-focus)
        save_focus
        ;;
    stack-new)
        # Give yabai a brief moment to finish managing the new AX window.
        sleep "${YABAI_AUTO_STACK_DELAY:-0.4}"
        stack_new_window
        ;;
    *)
        printf 'usage: %s save-focus|stack-new\n' "$0" >&2
        exit 2
        ;;
esac
