#!/usr/bin/env sh
set -eu

command="${1:-}"
argument="${2:-}"
STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/yabai"
TARGET_DISPLAY_FILE="$STATE_DIR/target-display"

mkdir -p "$STATE_DIR"

case "$command" in
    select-display|move-window-display|focus|move-window|focus-display|move-window-to)
        ;;
    *)
        printf 'usage: %s select-display|move-window-display <display>|prev|next|focus|move-window 1..10|focus-display|move-window-to <display> <slot>\n' "$0" >&2
        exit 2
        ;;
esac

focused_display() {
    display="$(yabai -m query --displays 2>/dev/null |
        jq -r '.[] | select(."has-focus" == true) | .index // empty')"

    if [ -z "$display" ]; then
        display="$(yabai -m query --windows --window 2>/dev/null | jq -r '.display // empty' || true)"
    fi

    printf '%s\n' "$display"
}

display_exists() {
    display="$1"
    yabai -m query --displays 2>/dev/null |
        jq -e --argjson display "$display" 'any(.[]; .index == $display)' >/dev/null 2>&1
}

target_display() {
    display=""

    if [ -f "$TARGET_DISPLAY_FILE" ]; then
        display="$(cat "$TARGET_DISPLAY_FILE")"
    fi

    if [ -z "$display" ] || ! display_exists "$display"; then
        display="$(focused_display)"
    fi

    printf '%s\n' "$display"
}

resolve_display() {
    requested="$1"
    current="$(target_display)"

    case "$requested" in
        prev|next)
            yabai -m query --displays 2>/dev/null |
                jq -r --arg current "$current" --arg direction "$requested" '
                    ([.[].index] | sort) as $displays
                    | ($current | tonumber?) as $current_display
                    | ($displays | index($current_display)) as $idx
                    | if ($idx == null) then
                        $displays[0]
                      elif $direction == "next" then
                        $displays[(($idx + 1) % ($displays | length))]
                      else
                        $displays[(($idx - 1 + ($displays | length)) % ($displays | length))]
                      end
                '
            ;;
        *)
            printf '%s\n' "$requested"
            ;;
    esac
}

select_display() {
    display="$(resolve_display "$1")"
    [ -n "$display" ] || exit 0
    display_exists "$display" || exit 0

    printf '%s\n' "$display" > "$TARGET_DISPLAY_FILE"
    yabai -m display --focus "$display" >/dev/null 2>&1 || true
}

move_window_to_display() {
    display="$(resolve_display "$1")"
    [ -n "$display" ] || exit 0
    display_exists "$display" || exit 0

    window="$(yabai -m query --windows --window 2>/dev/null | jq -r '.id // empty' || true)"
    printf '%s\n' "$display" > "$TARGET_DISPLAY_FILE"
    yabai -m window --display "$display" >/dev/null 2>&1 || true
    if [ -n "$window" ]; then
        yabai -m window --focus "$window" >/dev/null 2>&1 || true
    fi
    yabai -m display --focus "$display" >/dev/null 2>&1 || true
}

space_for_slot() {
    display="$1"
    slot="$2"

    yabai -m query --spaces 2>/dev/null |
        jq -r --argjson display "$display" --argjson slot "$slot" '
            [.[] | select(.display == $display) | .index] | sort | .[$slot - 1] // empty
        '
}

normalize_slot() {
    slot="$1"

    case "$slot" in
        1|2|3|4|5|6|7|8|9|10)
            ;;
        0)
            slot=10
            ;;
        *)
            printf 'usage: %s focus|move-window 1..10\n' "$0" >&2
            exit 2
            ;;
    esac

    printf '%s\n' "$slot"
}

first_window_in_space() {
    space="$1"

    yabai -m query --windows 2>/dev/null |
        jq -r --argjson space "$space" '
            [
                .[]
                | select(.space == $space)
                | select(."is-minimized" == false)
                | select(."is-hidden" == false)
            ]
            | sort_by([(."has-focus" | not), .id])
            | .[0].id // empty
        '
}

show_space_on_display() {
    display="$1"
    space="$2"

    yabai -m display "$display" --space "$space" >/dev/null 2>&1 || true
}

focus_or_show_space() {
    display="$1"
    space="$2"

    show_space_on_display "$display" "$space"

    window="$(first_window_in_space "$space")"
    if [ -n "$window" ]; then
        yabai -m window --focus "$window" >/dev/null 2>&1 || true
    fi
}

case "$command" in
    select-display)
        select_display "$argument"
        ;;
    move-window-display)
        move_window_to_display "$argument"
        ;;
    focus)
        slot="$(normalize_slot "$argument")"
        display="$(target_display)"
        [ -n "$display" ] || exit 0
        space="$(space_for_slot "$display" "$slot")"
        [ -n "$space" ] || exit 0
        focus_or_show_space "$display" "$space"
        ;;
    move-window)
        slot="$(normalize_slot "$argument")"
        display="$(target_display)"
        [ -n "$display" ] || exit 0
        space="$(space_for_slot "$display" "$slot")"
        [ -n "$space" ] || exit 0
        window="$(yabai -m query --windows --window 2>/dev/null | jq -r '.id // empty' || true)"
        show_space_on_display "$display" "$space"
        yabai -m window --space "$space" >/dev/null 2>&1 || true
        if [ -n "$window" ]; then
            yabai -m window --focus "$window" >/dev/null 2>&1 || true
        else
            focus_or_show_space "$display" "$space"
        fi
        ;;
    focus-display)
        display="$(resolve_display "$argument")"
        slot="$(normalize_slot "${3:-}")"
        [ -n "$display" ] || exit 0
        space="$(space_for_slot "$display" "$slot")"
        [ -n "$space" ] || exit 0
        printf '%s\n' "$display" > "$TARGET_DISPLAY_FILE"
        focus_or_show_space "$display" "$space"
        ;;
    move-window-to)
        display="$(resolve_display "$argument")"
        slot="$(normalize_slot "${3:-}")"
        [ -n "$display" ] || exit 0
        space="$(space_for_slot "$display" "$slot")"
        [ -n "$space" ] || exit 0
        window="$(yabai -m query --windows --window 2>/dev/null | jq -r '.id // empty' || true)"
        printf '%s\n' "$display" > "$TARGET_DISPLAY_FILE"
        show_space_on_display "$display" "$space"
        yabai -m window --space "$space" >/dev/null 2>&1 || true
        if [ -n "$window" ]; then
            yabai -m window --focus "$window" >/dev/null 2>&1 || true
        else
            focus_or_show_space "$display" "$space"
        fi
        ;;
esac
