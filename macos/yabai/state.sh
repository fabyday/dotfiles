#!/usr/bin/env sh
set -eu

STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/yabai"
STATE_FILE="${YABAI_STATE_FILE:-$STATE_DIR/window-state.json}"

mkdir -p "$STATE_DIR"

usage() {
    printf 'usage: %s save|restore|path\n' "$0" >&2
}

save_state() {
    tmp_file="$STATE_FILE.tmp"

    jq -n \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --argjson displays "$(yabai -m query --displays)" \
        --argjson spaces "$(yabai -m query --spaces)" \
        --argjson windows "$(yabai -m query --windows)" \
        '{
            timestamp: $timestamp,
            focused_window: ($windows[] | select(."has-focus" == true) | .id) // null,
            focused_space: ($spaces[] | select(."has-focus" == true) | .index) // null,
            displays: $displays,
            spaces: $spaces,
            windows: $windows
        }' > "$tmp_file"

    mv "$tmp_file" "$STATE_FILE"
    printf 'saved yabai state to %s\n' "$STATE_FILE"
}

restore_space_layouts() {
    jq -r '.spaces[] | [.index, .type] | @tsv' "$STATE_FILE" |
    while IFS="$(printf '\t')" read -r space_index layout; do
        [ -n "$space_index" ] || continue
        [ -n "$layout" ] || continue
        yabai -m space "$space_index" --layout "$layout" >/dev/null 2>&1 || true
    done
}

restore_windows() {
    current_ids="$(yabai -m query --windows | jq -r '.[].id')"

    jq -c --argjson displays "$(jq '.displays' "$STATE_FILE")" '
        def display_for($idx): $displays[] | select(.index == $idx);
        def covers_display($win; $display):
            ($win.frame.w >= ($display.frame.w * 0.95)) and
            ($win.frame.h >= ($display.frame.h * 0.95)) and
            ($win.frame.x <= ($display.frame.x + 8)) and
            ($win.frame.y <= ($display.frame.y + 8)) and
            (($win.frame.x + $win.frame.w) >= ($display.frame.x + $display.frame.w - 8)) and
            (($win.frame.y + $win.frame.h) >= ($display.frame.y + $display.frame.h - 8));
        def fullscreen_like:
            (display_for(.display) as $display
                | ."is-native-fullscreen" == true
                  or (((."can-move" == false) or (."can-resize" == false))
                      and covers_display(.; $display)));
        .windows[]
        | select(."is-minimized" == false)
        | select(fullscreen_like | not)
    ' "$STATE_FILE" |
    while IFS= read -r window; do
        id="$(printf '%s' "$window" | jq -r '.id')"
        printf '%s\n' "$current_ids" | grep -qx "$id" || continue

        space="$(printf '%s' "$window" | jq -r '.space')"
        is_floating="$(printf '%s' "$window" | jq -r '."is-floating"')"
        is_sticky="$(printf '%s' "$window" | jq -r '."is-sticky"')"

        yabai -m window "$id" --space "$space" >/dev/null 2>&1 || true

        current_floating="$(yabai -m query --windows --window "$id" | jq -r '."is-floating"')"
        if [ "$current_floating" != "$is_floating" ]; then
            yabai -m window "$id" --toggle float >/dev/null 2>&1 || true
        fi

        current_sticky="$(yabai -m query --windows --window "$id" | jq -r '."is-sticky"')"
        if [ "$current_sticky" != "$is_sticky" ]; then
            yabai -m window "$id" --toggle sticky >/dev/null 2>&1 || true
        fi

        if [ "$is_floating" = "true" ]; then
            x="$(printf '%s' "$window" | jq -r '.frame.x | floor')"
            y="$(printf '%s' "$window" | jq -r '.frame.y | floor')"
            w="$(printf '%s' "$window" | jq -r '.frame.w | floor')"
            h="$(printf '%s' "$window" | jq -r '.frame.h | floor')"
            yabai -m window "$id" --move "abs:$x:$y" >/dev/null 2>&1 || true
            yabai -m window "$id" --resize "abs:$w:$h" >/dev/null 2>&1 || true
        fi
    done
}

restore_focus() {
    focused_space="$(jq -r '.focused_space // empty' "$STATE_FILE")"
    focused_window="$(jq -r '.focused_window // empty' "$STATE_FILE")"

    [ -n "$focused_space" ] && yabai -m space --focus "$focused_space" >/dev/null 2>&1 || true
    [ -n "$focused_window" ] && yabai -m window --focus "$focused_window" >/dev/null 2>&1 || true
}

restore_state() {
    if [ ! -f "$STATE_FILE" ]; then
        printf 'no yabai state file found at %s\n' "$STATE_FILE" >&2
        exit 1
    fi

    restore_space_layouts
    restore_windows
    restore_focus
    printf 'restored yabai state from %s\n' "$STATE_FILE"
}

case "${1:-}" in
    save)
        save_state
        ;;
    restore)
        restore_state
        ;;
    path)
        printf '%s\n' "$STATE_FILE"
        ;;
    *)
        usage
        exit 2
        ;;
esac
