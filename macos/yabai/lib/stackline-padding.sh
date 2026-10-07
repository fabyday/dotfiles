#!/usr/bin/env sh
set -eu

base="${1:-8}"
gutter="${2:-52}"
yabai_bin="${3:-/opt/homebrew/bin/yabai}"
sides="${4:-left}"
force="${5:-}"
STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/yabai"
CACHE_FILE="$STATE_DIR/stackline-padding.json"
LOCK_FILE="$STATE_DIR/stackline-padding.lock"
mkdir -p "$STATE_DIR"

case "$base:$gutter" in
    *[!0-9:]*|:*|*:) exit 2 ;;
esac
case "$sides" in left|right|both) ;; *) exit 2 ;; esac

if [ "${6:-}" != "--locked" ]; then
    lock_timeout=0
    [ "$force" = --force ] && lock_timeout=10
    exec lockf -t "$lock_timeout" "$LOCK_FILE" sh "$0" "$base" "$gutter" "$yabai_bin" "$sides" "$force" --locked
fi

spaces="$("$yabai_bin" -m query --spaces 2>/dev/null)" || exit 0
windows="$("$yabai_bin" -m query --windows 2>/dev/null)" || exit 0

if [ "$force" = --force ]; then
    "$yabai_bin" -m config left_padding "$base"
    "$yabai_bin" -m config right_padding "$base"
    cache='{}'
elif [ -f "$CACHE_FILE" ] && jq -e 'type == "object"' "$CACHE_FILE" >/dev/null 2>&1; then
    cache="$(cat "$CACHE_FILE")"
else
    cache='{}'
fi

rows="$(jq -rn --argjson spaces "$spaces" --argjson windows "$windows" \
    --argjson base "$base" --argjson gutter "$gutter" --arg sides "$sides" '
    $spaces[] | select(.label != "" and .type == "bsp") as $space
    | ([$windows[] | select(.space == $space.index and (."stack-index" // 0) > 0)]
       | group_by([.frame.x, .frame.y, .frame.w, .frame.h])
       | any(.[]; length >= 2)) as $has_stack
    | [$space.label,
       (if $has_stack and ($sides == "left" or $sides == "both") then $gutter else $base end),
       (if $has_stack and ($sides == "right" or $sides == "both") then $gutter else $base end)] | @tsv
')"

while IFS="$(printf '\t')" read -r label desired_left desired_right; do
    [ -n "$label" ] || continue
    previous_left="$(printf '%s\n' "$cache" | jq -r --arg label "$label" '.[$label].left // empty')"
    previous_right="$(printf '%s\n' "$cache" | jq -r --arg label "$label" '.[$label].right // empty')"
    if [ "$previous_left" != "$desired_left" ]; then
        "$yabai_bin" -m config --space "$label" left_padding "$desired_left"
    fi
    if [ "$previous_right" != "$desired_right" ]; then
        "$yabai_bin" -m config --space "$label" right_padding "$desired_right"
    fi
    if [ "$previous_left" != "$desired_left" ] || [ "$previous_right" != "$desired_right" ]; then
        cache="$(printf '%s\n' "$cache" | jq -c --arg label "$label" --argjson left "$desired_left" --argjson right "$desired_right" '.[$label] = {left: $left, right: $right}')"
    fi
done <<ROWS
$rows
ROWS

temp_file="$(mktemp "$STATE_DIR/.stackline-padding.XXXXXX")"
printf '%s\n' "$cache" > "$temp_file"
mv "$temp_file" "$CACHE_FILE"
