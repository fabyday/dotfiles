#!/usr/bin/env sh
set -eu

command="${1:-}"
argument="${2:-}"
STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/yabai"
TARGET_DISPLAY_FILE="$STATE_DIR/target-display"
HISTORY_SCRIPT="$HOME/.config/yabai/lib/space-history.sh"

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
    # The pointer remains on an empty display after yabai focuses it, while
    # macOS may keep the last app window on another display as key window.
    display="$(yabai -m query --displays --display mouse 2>/dev/null |
        jq -r '.index // empty' || true)"

    if [ -z "$display" ]; then
        display="$(yabai -m query --displays 2>/dev/null |
            jq -r '.[] | select(."has-focus" == true) | .index // empty' || true)"
    fi

    if [ -z "$display" ]; then
        display="$(yabai -m query --windows --window 2>/dev/null | jq -r '.display // empty' || true)"
    fi

    if [ -z "$display" ]; then
        display="$(yabai -m query --displays 2>/dev/null | jq -r '.[0].index // empty' || true)"
    fi

    printf '%s\n' "$display"
}

display_exists() {
    display="$1"
    yabai -m query --displays 2>/dev/null |
        jq -e --argjson display "$display" 'any(.[]; .index == $display)' >/dev/null 2>&1
}

target_display() {
    # Display mode keeps its selected logical display even when focusing an
    # empty Space leaves macOS reporting another display as focused.
    display=""
    if [ -f "$TARGET_DISPLAY_FILE" ]; then
        saved_label="$(cat "$TARGET_DISPLAY_FILE")"
        display="$(yabai -m query --displays 2>/dev/null |
            jq -r --arg label "$saved_label" '.[] | select(.label == $label) | .index // empty')"
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
        current)
            focused_display
            ;;
        prev|next)
            yabai -m query --displays 2>/dev/null |
                jq -r --arg current "$current" --arg direction "$requested" '
                    ([.[].index] | sort) as $displays
                    | ($current | tonumber?) as $current_display
                    | ($displays | index($current_display)) as $idx
                    | if ($displays | length) == 0 then
                        empty
                      elif ($idx == null) then
                        $displays[0]
                      elif $direction == "next" then
                        $displays[(($idx + 1) % ($displays | length))]
                      else
                        $displays[(($idx - 1 + ($displays | length)) % ($displays | length))]
                      end
                '
            ;;
        *)
            yabai -m query --displays 2>/dev/null |
                jq -r --arg label "d$requested" '.[] | select(.label == $label) | .index // empty'
            ;;
    esac
}

select_display() {
    display="$(resolve_display "$1")"
    [ -n "$display" ] || exit 0
    display_exists "$display" || exit 0

    display_label="$(yabai -m query --displays | jq -r --argjson index "$display" '.[] | select(.index == $index) | .label')"
    printf '%s\n' "$display_label" > "$TARGET_DISPLAY_FILE"
    yabai -m display --focus "$display_label" >/dev/null 2>&1 || true
}

move_window_to_display() {
    display="$(resolve_display "$1")"
    [ -n "$display" ] || exit 0
    display_exists "$display" || exit 0

    window_json="$(yabai -m query --windows --window 2>/dev/null || true)"
    window="$(printf '%s\n' "$window_json" | jq -r '.id // empty' || true)"
    window_display="$(printf '%s\n' "$window_json" | jq -r '.display // empty' || true)"
    display_label="$(yabai -m query --displays | jq -r --argjson index "$display" '.[] | select(.index == $index) | .label')"
    if [ -z "$window" ]; then
        printf 'no focused window to move\n' >&2
        return 1
    fi
    if [ "$window_display" != "$display" ]; then
        yabai -m window "$window" --display "$display_label"
    fi
    printf '%s\n' "$display_label" > "$TARGET_DISPLAY_FILE"
    if [ -n "$window" ]; then
        yabai -m window --focus "$window" >/dev/null 2>&1 || true
    fi
    yabai -m display --focus "$display_label" >/dev/null 2>&1 || true
}

space_for_slot() {
    display="$1"
    slot="$2"
    display_label="$(yabai -m query --displays 2>/dev/null |
        jq -r --argjson index "$display" '.[] | select(.index == $index) | .label')"
    [ -n "$display_label" ] || return 0

    yabai -m query --spaces 2>/dev/null |
        jq -r --arg label "${display_label}s${slot}" '
            [.[] | select(.label == $label)] | first | .label // empty
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

focus_or_show_space() {
    display="$1"
    space="$2"

    # A Space can have no focusable window. Focusing an arbitrary window after
    # switching may bring its app's previous Space back into view.
    if ! yabai -m space --focus "$space" >/dev/null 2>&1; then
        visible_space="$(yabai -m query --spaces 2>/dev/null |
            jq -r --argjson display "$display" '.[] | select(.display == $display and ."is-visible" == true) | .label // empty')"
        [ "$visible_space" = "$space" ] || return 1
    fi

    sh "$HISTORY_SCRIPT" record "$space" >/dev/null 2>&1 || true
}

move_focused_window_to_space() {
    space="$1"
    window="$(yabai -m query --windows --window | jq -r '.id // empty')"
    if [ -z "$window" ]; then
        printf 'no focused window to move\n' >&2
        return 1
    fi

    yabai -m window "$window" --space "$space"
    yabai -m space --focus "$space" >/dev/null 2>&1 || true
    yabai -m window --focus "$window" >/dev/null 2>&1 || true
    sh "$HISTORY_SCRIPT" record "$space" >/dev/null 2>&1 || true
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
        move_focused_window_to_space "$space"
        ;;
    focus-display)
        display="$(resolve_display "$argument")"
        slot="$(normalize_slot "${3:-}")"
        [ -n "$display" ] || exit 0
        space="$(space_for_slot "$display" "$slot")"
        [ -n "$space" ] || exit 0
        yabai -m query --displays | jq -r --argjson index "$display" '.[] | select(.index == $index) | .label' > "$TARGET_DISPLAY_FILE"
        focus_or_show_space "$display" "$space"
        ;;
    move-window-to)
        display="$(resolve_display "$argument")"
        slot="$(normalize_slot "${3:-}")"
        [ -n "$display" ] || exit 0
        space="$(space_for_slot "$display" "$slot")"
        [ -n "$space" ] || exit 0
        yabai -m query --displays | jq -r --argjson index "$display" '.[] | select(.index == $index) | .label' > "$TARGET_DISPLAY_FILE"
        move_focused_window_to_space "$space"
        ;;
esac
