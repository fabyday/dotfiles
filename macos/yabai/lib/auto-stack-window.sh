#!/usr/bin/env sh
set -eu

STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/yabai"
LOCK_FILE="$STATE_DIR/auto-stack.lock"
NEW_WINDOW_MODE="$HOME/.config/yabai/lib/new-window-mode.sh"
mkdir -p "$STATE_DIR"

query_window() {
    yabai -m query --windows --window "$1" 2>/dev/null || true
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

    global_current="$STATE_DIR/focused-window-global"
    global_previous="$STATE_DIR/previous-window-global"
    global_old="$(cat "$global_current" 2>/dev/null || true)"
    if [ -n "$global_old" ] && [ "$global_old" != "$window_id" ]; then
        printf '%s\n' "$global_old" > "$global_previous"
    fi
    printf '%s\n' "$window_id" > "$global_current"

}

stack_new_window() {
    [ "$(sh "$NEW_WINDOW_MODE" get)" = stack ] || exit 0
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
    [ "$(printf '%s' "$window_json" | jq -r '."stack-index" // 0')" = "0" ] || exit 0

    # Wait for space rules to settle before attempting a single stack.
    sleep "${YABAI_AUTO_STACK_SETTLE_DELAY:-0.3}"
    settled_json="$(query_window "$new_window")"
    [ -n "$settled_json" ] || exit 0
    [ "$(printf '%s' "$settled_json" | jq -r '.display // empty')" = "$display" ] || exit 0
    [ "$(printf '%s' "$settled_json" | jq -r '.space // empty')" = "$space" ] || exit 0

    focused_window="$(cat "$STATE_DIR/focused-window-global" 2>/dev/null || true)"
    if [ "$focused_window" = "$new_window" ]; then
        anchor="$(cat "$STATE_DIR/previous-window-global" 2>/dev/null || true)"
    else
        anchor="$focused_window"
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
        attempt_file="$STATE_DIR/auto-stack-attempt-$new_window"
        now="$(date +%s)"
        last_attempt="$(cat "$attempt_file" 2>/dev/null || printf 0)"
        case "$last_attempt" in *[!0-9]*|'') last_attempt=0 ;; esac
        [ "$((now - last_attempt))" -ge 30 ] || exit 0
        printf '%s\n' "$now" > "$attempt_file"
        yabai -m window "$anchor" --stack "$new_window" >/dev/null 2>&1 || true
    fi
}

case "${1:-}" in
    save-focus)
        save_focus
        ;;
    stack-new)
        [ "$(sh "$NEW_WINDOW_MODE" get)" = stack ] || exit 0
        # Give yabai a brief moment to finish managing the new AX window.
        sleep "${YABAI_AUTO_STACK_DELAY:-0.4}"
        exec lockf -t 30 "$LOCK_FILE" sh "$0" --stack-new-locked
        ;;
    --stack-new-locked)
        stack_new_window
        ;;
    *)
        printf 'usage: %s save-focus|stack-new\n' "$0" >&2
        exit 2
        ;;
esac
