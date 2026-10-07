#!/usr/bin/env sh
set -eu

direction="${1:-east}"
case "$direction" in
    north|east|south|west) ;;
    *) printf 'usage: %s north|east|south|west\n' "$0" >&2; exit 2 ;;
esac

current="$(yabai -m query --windows --window)"
id="$(printf '%s\n' "$current" | jq -r '.id // empty')"
space="$(printf '%s\n' "$current" | jq -r '.space // empty')"
stack_index="$(printf '%s\n' "$current" | jq -r '."stack-index" // 0')"
if [ -z "$id" ] || [ "$stack_index" -le 0 ]; then
    printf 'the focused window is not in a stack\n' >&2
    exit 1
fi

layout="$(yabai -m query --spaces | jq -r --argjson space "$space" '.[] | select(.index == $space) | .type // empty')"
if [ "$layout" != bsp ]; then
    printf 'the current space is not a BSP space\n' >&2
    exit 1
fi

companion="$(yabai -m query --windows | jq -r --argjson current "$current" '
    [.[] | select(.id != $current.id and .space == $current.space
        and ."stack-index" > 0 and .frame == $current.frame)]
    | sort_by(."stack-index") | first | .id // empty
')"
if [ -z "$companion" ]; then
    printf 'no other window was found in the focused stack\n' >&2
    exit 1
fi

# Temporarily remove the selected window from the BSP tree. The remaining
# stack is then the insertion target, even when it is the only BSP node.
yabai -m window "$id" --toggle float
if ! yabai -m window "$companion" --insert stack ||
   ! yabai -m window "$companion" --insert "$direction"; then
    yabai -m window "$id" --toggle float >/dev/null 2>&1 || true
    exit 1
fi
if ! yabai -m window "$id" --toggle float; then
    yabai -m window "$companion" --insert "$direction" >/dev/null 2>&1 || true
    exit 1
fi

result="$(yabai -m query --windows --window "$id")"
if [ "$(printf '%s\n' "$result" | jq -r '."is-floating"')" != false ] ||
   [ "$(printf '%s\n' "$result" | jq -r '."stack-index"')" != 0 ]; then
    printf 'the selected window did not become a separate BSP node\n' >&2
    exit 1
fi
yabai -m window --focus "$id" >/dev/null 2>&1 || true
