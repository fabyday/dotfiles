#!/usr/bin/env sh
set -eu

SPACES_PER_DISPLAY="${YABAI_SPACES_PER_DISPLAY:-10}"
MAX_DISPLAYS="${SKETCHYBAR_MAX_DISPLAYS:-6}"
LOCK_DIR="${TMPDIR:-/tmp}/sketchybar-update-spaces.lock"

if ! command -v yabai >/dev/null 2>&1 || ! command -v sketchybar >/dev/null 2>&1; then
    exit 0
fi

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    exit 0
fi

trap 'rmdir "$LOCK_DIR"' EXIT INT TERM

spaces_json="$(yabai -m query --spaces 2>/dev/null || printf '[]')"
displays_json="$(yabai -m query --displays 2>/dev/null || printf '[]')"

display=1
while [ "$display" -le "$MAX_DISPLAYS" ]; do
    if printf '%s\n' "$displays_json" | jq -e --argjson display "$display" 'any(.[]; .index == $display)' >/dev/null; then
        sketchybar --set "display.$display" drawing=on >/dev/null 2>&1 || true
    else
        sketchybar --set "display.$display" drawing=off >/dev/null 2>&1 || true
    fi

    slot=1
    while [ "$slot" -le "$SPACES_PER_DISPLAY" ]; do
        item="space.d${display}s${slot}"
        expected_index=$(((display - 1) * SPACES_PER_DISPLAY + slot))

        space_row="$(
            printf '%s\n' "$spaces_json" |
                jq -r --argjson display "$display" --argjson slot "$slot" --argjson expected "$expected_index" '
                    .[]
                    | select(.display == $display)
                    | select(
                        .label == ("d" + ($display | tostring) + "s" + ($slot | tostring))
                        or .index == $expected
                    )
                    | [.index, ."has-focus", ."is-visible"] | @tsv
                ' |
                head -n 1
        )"

        if [ -z "$space_row" ]; then
            sketchybar --set "$item" drawing=off >/dev/null 2>&1 || true
            slot=$((slot + 1))
            continue
        fi

        sid="$(printf '%s\n' "$space_row" | awk -F '\t' '{print $1}')"
        has_focus="$(printf '%s\n' "$space_row" | awk -F '\t' '{print $2}')"
        is_visible="$(printf '%s\n' "$space_row" | awk -F '\t' '{print $3}')"

        if [ "$has_focus" = "true" ]; then
            icon_color="0xff111827"
            background_color="0xffd1d5db"
            border_color="0xffd1d5db"
        elif [ "$is_visible" = "true" ]; then
            icon_color="0xffe5e7eb"
            background_color="0x66525660"
            border_color="0xff9ca3af"
        else
            icon_color="0xff9ca3af"
            background_color="0x332a2a33"
            border_color="0x00000000"
        fi

        sketchybar --set "$item" \
            drawing=on \
            icon="$slot" \
            icon.color="$icon_color" \
            background.color="$background_color" \
            background.border_color="$border_color" \
            click_script="yabai -m display $display --space $sid; yabai -m space --focus $sid >/dev/null 2>&1 || true" \
            >/dev/null 2>&1 || true

        slot=$((slot + 1))
    done

    display=$((display + 1))
done
