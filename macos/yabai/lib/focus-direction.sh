#!/usr/bin/env sh
set -eu

direction="${1:-}"

case "$direction" in
    west|south|north|east)
        ;;
    *)
        printf 'usage: %s west|south|north|east\n' "$0" >&2
        exit 2
        ;;
esac

current_json="$(yabai -m query --windows --window 2>/dev/null || true)"
[ -n "$current_json" ] || exit 0

current_id="$(printf '%s\n' "$current_json" | jq -r '.id // empty')"
[ -n "$current_id" ] || exit 0

yabai -m window --focus "$direction" >/dev/null 2>&1 || true

focused_id="$(yabai -m query --windows --window 2>/dev/null | jq -r '.id // empty' || true)"
if [ -n "$focused_id" ] && [ "$focused_id" != "$current_id" ]; then
    exit 0
fi

target_id="$(
    yabai -m query --windows 2>/dev/null |
        jq -r --argjson current "$current_json" --arg direction "$direction" '
            def cx: .frame.x + (.frame.w / 2);
            def cy: .frame.y + (.frame.h / 2);
            def left: .frame.x;
            def right: .frame.x + .frame.w;
            def top: .frame.y;
            def bottom: .frame.y + .frame.h;
            def overlap_y($a; $b): ([($a | bottom), ($b | bottom)] | min) - ([($a | top), ($b | top)] | max);
            def overlap_x($a; $b): ([($a | right), ($b | right)] | min) - ([($a | left), ($b | left)] | max);
            def abs: if . < 0 then -. else . end;

            . as $windows
            | ($current | cx) as $cx
            | ($current | cy) as $cy
            | [
                $windows[]
                | select(.id != $current.id)
                | select(.display == $current.display)
                | select(.space == $current.space)
                | select(."is-minimized" == false)
                | select(."is-hidden" == false)
                | . + {
                    directional_distance:
                        (if $direction == "west" then $cx - (cx)
                         elif $direction == "east" then (cx) - $cx
                         elif $direction == "north" then $cy - (cy)
                         else (cy) - $cy end),
                    cross_distance:
                        (if ($direction == "west" or $direction == "east") then ((cy) - $cy | abs)
                         else ((cx) - $cx | abs) end),
                    overlaps_axis:
                        (if ($direction == "west" or $direction == "east") then (overlap_y($current; .) > 0)
                         else (overlap_x($current; .) > 0) end)
                }
                | select(.directional_distance > 0)
            ]
            | sort_by((.overlaps_axis | not), .directional_distance, .cross_distance)
            | .[0].id // empty
        '
)"

if [ -n "$target_id" ]; then
    yabai -m window --focus "$target_id" >/dev/null 2>&1 || true
else
    yabai -m window --focus recent >/dev/null 2>&1 || true
fi
