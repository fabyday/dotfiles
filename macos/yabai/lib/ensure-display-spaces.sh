#!/usr/bin/env sh
set -eu

TARGET_SPACES_PER_DISPLAY="${YABAI_SPACES_PER_DISPLAY:-10}"
LOCK_FILE="${TMPDIR:-/tmp}/yabai-ensure-display-spaces.lock"

if [ "${1:-}" != "--locked" ]; then
    exec lockf -t 10 "$LOCK_FILE" sh "$0" --locked
fi

focused_space="$(yabai -m query --spaces 2>/dev/null |
    jq -r '.[] | select(."has-focus" == true) | .index // empty' || true)"

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
    display="$1"
    slot="$2"
    yabai -m query --spaces 2>/dev/null |
        jq -r --arg label "d${display}s${slot}" --argjson display "$display" \
            --argjson expected "$(((display - 1) * TARGET_SPACES_PER_DISPLAY + slot))" '
            ([.[] | select(.label == $label)] | first | .index) //
            ([.[] | select(.display == $display and .label == "" and .index == $expected)] | first | .index) //
            ([.[] | select(.display == $display and .label == "")] | first | .index) // empty
        '
}

displays="$(yabai -m query --displays 2>/dev/null | jq -r '[.[].index] | sort | .[]')"

printf '%s\n' "$displays" |
while IFS= read -r display; do
    [ -n "$display" ] || continue

    slot=1
    while [ "$slot" -le "$TARGET_SPACES_PER_DISPLAY" ]; do
        target_space="$(space_for_slot "$display" "$slot")"
        if [ -z "$target_space" ]; then
            yabai -m space --create "$display" >/dev/null 2>&1 || break
            sleep 0.35
            target_space="$(space_for_slot "$display" "$slot")"
        fi
        [ -n "$target_space" ] || break

        current_display="$(space_display "$target_space")"
        if [ "$current_display" != "$display" ]; then
            yabai -m space "$target_space" --display "$display" >/dev/null 2>&1 || true
            sleep 0.15
        fi
        desired_label="d${display}s${slot}"
        current_label="$(space_label "$target_space")"
        if [ "$current_label" != "$desired_label" ]; then
            yabai -m space "$target_space" --label "$desired_label" >/dev/null 2>&1 || true
        fi

        slot=$((slot + 1))
    done
done

if [ -n "$focused_space" ]; then
    current_focus="$(yabai -m query --spaces 2>/dev/null |
        jq -r '.[] | select(."has-focus" == true) | .index // empty' || true)"
    if [ "$current_focus" != "$focused_space" ]; then
        yabai -m space --focus "$focused_space" >/dev/null 2>&1 || true
    fi
fi

if command -v sketchybar >/dev/null 2>&1; then
    sketchybar --trigger yabai_spaces_changed >/dev/null 2>&1 || true
fi
