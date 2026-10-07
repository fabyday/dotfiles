#!/usr/bin/env sh
set -eu

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/yabai"
MAP_FILE="$STATE_DIR/display-uuids.json"
LOCK_FILE="$STATE_DIR/display-uuids.lock"
mkdir -p "$STATE_DIR"

if [ "${1:-}" != "--locked" ]; then
    exec lockf -t 10 "$LOCK_FILE" sh "$0" --locked
fi

displays="$(yabai -m query --displays)"
if [ -f "$MAP_FILE" ] && jq -e 'type == "object"' "$MAP_FILE" >/dev/null 2>&1; then
    map="$(cat "$MAP_FILE")"
else
    map='{}'
fi

rows="$(printf '%s\n' "$displays" | jq -r 'sort_by(.index)[] | [.uuid, .index, .label] | @tsv')"
assignments=""
while IFS="$(printf '\t')" read -r uuid index current_label; do
    [ -n "$uuid" ] || continue
    label="$(printf '%s\n' "$map" | jq -r --arg uuid "$uuid" '.[$uuid] // empty')"

    if [ -z "$label" ] && printf '%s\n' "$current_label" | grep -Eq '^d[1-9][0-9]*$'; then
        if ! printf '%s\n' "$map" | jq -e --arg label "$current_label" 'any(.[]; . == $label)' >/dev/null; then
            label="$current_label"
        fi
    fi

    if [ -z "$label" ]; then
        candidate="$index"
        while printf '%s\n' "$map" | jq -e --arg label "d$candidate" 'any(.[]; . == $label)' >/dev/null; do
            candidate=$((candidate + 1))
        done
        label="d$candidate"
    fi

    map="$(printf '%s\n' "$map" | jq -c --arg uuid "$uuid" --arg label "$label" '.[$uuid] = $label')"
    assignments="${assignments}${index} ${current_label:-none} ${label}
"
done <<ROWS
$rows
ROWS

# Clear mismatched labels first so two displays can exchange labels without
# colliding with a label still held by the other display.
printf '%s\n' "$assignments" | while read -r index current_label label; do
    [ -n "$index" ] || continue
    if [ "$current_label" != none ] && [ "$current_label" != "$label" ]; then
        yabai -m display "$index" --label
    fi
done
printf '%s\n' "$assignments" | while read -r index current_label label; do
    [ -n "$index" ] || continue
    if [ "$current_label" != "$label" ]; then
        yabai -m display "$index" --label "$label"
    fi
done

temp_file="$(mktemp "$STATE_DIR/.display-uuids.XXXXXX")"
printf '%s\n' "$map" > "$temp_file"
mv "$temp_file" "$MAP_FILE"
