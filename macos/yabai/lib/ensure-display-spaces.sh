#!/usr/bin/env sh
set -eu

TARGET_SPACES_PER_DISPLAY="${YABAI_SPACES_PER_DISPLAY:-10}"
LOCK_FILE="${TMPDIR:-/tmp}/yabai-ensure-display-spaces.lock"
LABEL_SCRIPT="$HOME/.config/yabai/lib/ensure-display-labels.sh"

if [ "${1:-}" != "--locked" ]; then
    exec lockf -t 10 "$LOCK_FILE" sh "$0" --locked
fi

sh "$LABEL_SCRIPT" || exit 1

focused_space="$(yabai -m query --spaces 2>/dev/null |
    jq -r '.[] | select(."has-focus" == true) | .label // empty' || true)"

space_display() {
    space="$1"
    yabai -m query --spaces 2>/dev/null |
        jq -r --argjson space "$space" '.[] | select(.index == $space) | .display // empty'
}

space_label() {
    space="$1"
    yabai -m query --spaces 2>/dev/null |
        jq -r --argjson space "$space" '.[] | select(.index == $space) | .label // empty'
}

space_for_slot() {
    display_label="$1"
    slot="$2"
    display_index="$(yabai -m query --displays 2>/dev/null |
        jq -r --arg label "$display_label" '.[] | select(.label == $label) | .index')"
    [ -n "$display_index" ] || return 0
    yabai -m query --spaces 2>/dev/null |
        jq -r --arg label "${display_label}s${slot}" \
            --argjson display "$display_index" '
            ([.[] | select(.label == $label)] | first | .index) //
            ([.[] | select(.display == $display and .label == "")] | sort_by(.index) | first | .index) // empty
        '
}

displays="$(yabai -m query --displays 2>/dev/null | jq -r 'sort_by(.index)[] | .label')"

printf '%s\n' "$displays" |
while IFS= read -r display_label; do
    [ -n "$display_label" ] || continue

    slot=1
    while [ "$slot" -le "$TARGET_SPACES_PER_DISPLAY" ]; do
        target_space="$(space_for_slot "$display_label" "$slot")"
        if [ -z "$target_space" ]; then
            yabai -m space --create "$display_label" >/dev/null 2>&1 || break
            sleep 0.35
            target_space="$(space_for_slot "$display_label" "$slot")"
        fi
        [ -n "$target_space" ] || break

        current_display="$(space_display "$target_space")"
        desired_display="$(yabai -m query --displays | jq -r --arg label "$display_label" '.[] | select(.label == $label) | .index')"
        if [ "$current_display" != "$desired_display" ]; then
            yabai -m space "$target_space" --display "$display_label" >/dev/null 2>&1 || true
            sleep 0.15
        fi
        desired_label="${display_label}s${slot}"
        current_label="$(space_label "$target_space")"
        if [ "$current_label" != "$desired_label" ]; then
            yabai -m space "$target_space" --label "$desired_label" >/dev/null 2>&1 || true
        fi

        slot=$((slot + 1))
    done
done

if [ -n "$focused_space" ]; then
    current_focus="$(yabai -m query --spaces 2>/dev/null |
        jq -r '.[] | select(."has-focus" == true) | .label // empty' || true)"
    if [ "$current_focus" != "$focused_space" ]; then
        yabai -m space --focus "$focused_space" >/dev/null 2>&1 || true
    fi
fi

if command -v sketchybar >/dev/null 2>&1; then
    sketchybar --trigger yabai_spaces_changed >/dev/null 2>&1 || true
fi
