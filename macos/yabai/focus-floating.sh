#!/usr/bin/env sh
set -eu

direction="${1:-next}"

case "$direction" in
    next|prev)
        ;;
    *)
        printf 'usage: %s next|prev\n' "$0" >&2
        exit 2
        ;;
esac

current_json="$(yabai -m query --windows --window 2>/dev/null || true)"
[ -n "$current_json" ] || exit 0

target_id="$(
    yabai -m query --windows 2>/dev/null |
        jq -r --argjson current "$current_json" --arg direction "$direction" '
            [
                .[]
                | select(.display == $current.display)
                | select(.space == $current.space)
                | select(."is-floating" == true)
                | select(."is-minimized" == false)
                | select(."is-hidden" == false)
            ]
            | sort_by(.id) as $floats
            | if ($floats | length) == 0 then
                empty
              elif ($floats | length) == 1 then
                $floats[0].id
              else
                ($floats | map(.id) | index($current.id)) as $idx
                | if $idx == null then
                    $floats[0].id
                  elif $direction == "next" then
                    $floats[(($idx + 1) % ($floats | length))].id
                  else
                    $floats[(($idx - 1 + ($floats | length)) % ($floats | length))].id
                  end
              end
        '
)"

[ -n "$target_id" ] || exit 0
yabai -m window --focus "$target_id" >/dev/null 2>&1 || true
