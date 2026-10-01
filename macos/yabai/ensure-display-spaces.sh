#!/usr/bin/env sh
set -eu

TARGET_SPACES_PER_DISPLAY="${YABAI_SPACES_PER_DISPLAY:-10}"
LOCK_DIR="${TMPDIR:-/tmp}/yabai-ensure-display-spaces.lock"

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    exit 0
fi

trap 'rmdir "$LOCK_DIR"' EXIT INT TERM

focused_space="$(yabai -m query --spaces 2>/dev/null |
    jq -r '.[] | select(."has-focus" == true) | .index // empty' || true)"

space_count_for_display() {
    display="$1"
    yabai -m query --spaces 2>/dev/null |
        jq -r --argjson display "$display" '[.[] | select(.display == $display)] | length'
}

space_exists() {
    space="$1"
    yabai -m query --spaces 2>/dev/null |
        jq -e --argjson space "$space" 'any(.[]; .index == $space)' >/dev/null 2>&1
}

space_display() {
    space="$1"
    yabai -m query --spaces 2>/dev/null |
        jq -r --argjson space "$space" '.[] | select(.index == $space) | .display // empty'
}

displays="$(yabai -m query --displays 2>/dev/null | jq -r '[.[].index] | sort | .[]')"
display_count="$(printf '%s\n' "$displays" | sed '/^$/d' | wc -l | tr -d ' ')"
target_total_spaces=$((display_count * TARGET_SPACES_PER_DISPLAY))

while ! space_exists "$target_total_spaces"; do
    last_display="$(printf '%s\n' "$displays" | tail -n 1)"
    [ -n "$last_display" ] || break
    yabai -m space --create "$last_display" >/dev/null 2>&1 || break
    sleep 0.35
done

printf '%s\n' "$displays" |
while IFS= read -r display; do
    [ -n "$display" ] || continue

    slot=1
    while [ "$slot" -le "$TARGET_SPACES_PER_DISPLAY" ]; do
        target_space=$(((display - 1) * TARGET_SPACES_PER_DISPLAY + slot))
        if space_exists "$target_space"; then
            current_display="$(space_display "$target_space")"
            if [ "$current_display" != "$display" ]; then
                yabai -m space "$target_space" --display "$display" >/dev/null 2>&1 || true
                sleep 0.15
            fi
            yabai -m space "$target_space" --label "d${display}s${slot}" >/dev/null 2>&1 || true
        fi

        slot=$((slot + 1))
    done
done

if [ -n "$focused_space" ]; then
    yabai -m space --focus "$focused_space" >/dev/null 2>&1 || true
fi

if command -v sketchybar >/dev/null 2>&1; then
    sketchybar --trigger yabai_spaces_changed >/dev/null 2>&1 || true
fi
