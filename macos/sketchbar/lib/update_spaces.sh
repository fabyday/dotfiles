#!/usr/bin/env sh
set -eu

SPACES_PER_DISPLAY="${YABAI_SPACES_PER_DISPLAY:-10}"
MAX_DISPLAYS="${SKETCHYBAR_MAX_DISPLAYS:-6}"
LOCK_FILE="${TMPDIR:-/tmp}/sketchybar-update-spaces.lock"

if [ "${1:-}" != "--locked" ]; then
    lockf -t 0 "$LOCK_FILE" sh "$0" --locked >/dev/null 2>&1 || true
    exit 0
fi

command -v yabai >/dev/null 2>&1 || exit 0
command -v sketchybar >/dev/null 2>&1 || exit 0

spaces_json="$(yabai -m query --spaces 2>/dev/null)" || exit 0
displays_json="$(yabai -m query --displays 2>/dev/null)" || exit 0

# Labels identify the logical display even while macOS temporarily moves its
# spaces to another monitor. In that case, show only occupied spaces there.
rows="$(jq -rn \
    --argjson spaces "$spaces_json" \
    --argjson displays "$displays_json" \
    --argjson per "$SPACES_PER_DISPLAY" \
    --argjson max "$MAX_DISPLAYS" '
    def space_for($group; $slot):
        ([$spaces[] | select(.label == ("d" + ($group | tostring) + "s" + ($slot | tostring)))] | first);
    ($displays | map(.index) | sort) as $connected_displays
    | ($connected_displays[0] // 1) as $fallback
    | range(1; $max + 1) as $group
    | ([$displays[] | select(.label == ("d" + ($group | tostring))) | .index] | first) as $connected_index
    | ($connected_index != null) as $connected
    | [range(1; $per + 1) as $slot
        | space_for($group; $slot) as $space
        | {slot: $slot, space: $space,
           show: ($space != null and ($connected or (($space.windows // []) | length > 0)))}
      ] as $slots
    | ([$slots[] | select(.show) | .space.display] | unique) as $hosts
    | ([$group, 0, (if $connected or ($hosts | length > 0) then "on" else "off" end),
        (if $connected then ($connected_index | tostring)
         elif ($hosts | length > 0) then ($hosts | map(tostring) | join(" "))
         else ($fallback | tostring) end),
        ([$slots[] | select(.show) | .space.index] | first // 0), $connected,
        ([$slots[] | select(.show) | .space.label] | first // "")] | @tsv),
      ($slots[]
        | [$group, .slot, (if .show then "on" else "off" end),
           (if .show then (.space.display | tostring) else ($fallback | tostring) end),
           (.space.index // 0), (.space."has-focus" // false), (.space."is-visible" // false)]
        | @tsv)
')" || exit 0

set --
while IFS="$(printf '\t')" read -r group slot drawing host sid has_focus is_visible; do
    if [ "$slot" = "0" ]; then
        set -- "$@" --set "display.$group" "drawing=$drawing" "display=$host"
        if [ "$drawing" = "on" ]; then
            if [ "$has_focus" = "true" ]; then
                set -- "$@" "click_script=sh ~/.config/yabai/lib/display-space.sh select-display $group"
            else
                set -- "$@" "click_script=yabai -m space --focus $is_visible"
            fi
        fi
        continue
    fi

    item="space.d${group}s${slot}"
    set -- "$@" --set "$item" "drawing=$drawing" "display=$host"
    [ "$drawing" = "on" ] || continue

    # Each display has an active visible Space, even when an empty Space has
    # no focused window and yabai reports focus on another display.
    if [ "$is_visible" = "true" ]; then
        icon_color="0xff111827"
        background_color="0xffd1d5db"
        border_color="0xffd1d5db"
    else
        icon_color="0xff9ca3af"
        background_color="0x332a2a33"
        border_color="0x00000000"
    fi

    set -- "$@" "icon=$slot" "icon.color=$icon_color" \
        "background.color=$background_color" "background.border_color=$border_color" \
        "click_script=yabai -m space --focus d${group}s${slot} >/dev/null 2>&1 || true"
done <<ROWS
$rows
ROWS

[ "$#" -gt 0 ] && sketchybar "$@" >/dev/null 2>&1 || true
