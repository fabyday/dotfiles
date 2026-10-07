#!/usr/bin/env sh
set -eu

STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/yabai"
LOCK_FILE="$STATE_DIR/space-history.lock"
LIMIT=10
mkdir -p "$STATE_DIR"

if [ "${1:-}" != "--locked" ]; then
    exec lockf -t 5 "$LOCK_FILE" sh "$0" --locked "$@"
fi
shift
command="${1:-}"
requested="${2:-}"

spaces_json="$(yabai -m query --spaces 2>/dev/null)" || exit 0

find_space() {
    printf '%s\n' "$spaces_json" | jq -c --arg requested "$1" '
        (try ($requested | tonumber) catch null) as $index
        | [.[] | select(if $index == null then ."has-focus" == true else .index == $index end)]
        | first // empty
    '
}

load_state() {
    if [ -f "$state_file" ] && jq -e '.entries | type == "array"' "$state_file" >/dev/null 2>&1; then
        cat "$state_file"
    else
        printf '{"entries":[],"cursor":-1}\n'
    fi
}

write_state() {
    temp_file="$(mktemp "$STATE_DIR/.space-history.XXXXXX")"
    printf '%s\n' "$1" > "$temp_file"
    mv "$temp_file" "$state_file"
}

select_history() {
    space_json="$1"
    key="$(printf '%s\n' "$space_json" | jq -r 'if (.label // "") != "" then .label else "id:" + (.id | tostring) end')"
    group="$(printf '%s\n' "$space_json" | jq -r '
        if ((.label // "") | test("^d[0-9]+s[0-9]+$"))
        then (.label | capture("^d(?<display>[0-9]+)s").display)
        else (.display | tostring) end
    ')"
    state_file="$STATE_DIR/space-history-display-$group.json"
}

record_space() {
    [ -n "$1" ] || return 0
    select_history "$1"
    state_json="$(load_state)"
    updated="$(printf '%s\n' "$state_json" | jq -c --arg key "$key" --argjson limit "$LIMIT" '
        (.entries // []) as $entries
        | (.cursor // (($entries | length) - 1)) as $cursor
        | if $entries[$cursor] == $key then
            .
          else
            ($entries[:($cursor + 1)] + [$key]) as $branched
            | (if ($branched | length) > $limit then $branched[-$limit:] else $branched end) as $trimmed
            | {entries: $trimmed, cursor: (($trimmed | length) - 1)}
          end
    ')"
    if [ "$updated" != "$state_json" ]; then
        write_state "$updated"
    fi
}

case "$command" in
    seed)
        visible="$(printf '%s\n' "$spaces_json" | jq -r '.[] | select(."is-visible" == true) | .index')"
        while IFS= read -r index; do
            [ -n "$index" ] || continue
            record_space "$(find_space "$index")"
        done <<VISIBLE
$visible
VISIBLE
        ;;
    record)
        record_space "$(find_space "$requested")"
        ;;
    prev|next)
        current="$(find_space "")"
        [ -n "$current" ] || exit 0
        record_space "$current"
        select_history "$current"
        state_json="$(load_state)"
        cursor="$(printf '%s\n' "$state_json" | jq -r '.cursor')"
        length="$(printf '%s\n' "$state_json" | jq -r '.entries | length')"
        if [ "$command" = prev ]; then step=-1; else step=1; fi
        candidate=$((cursor + step))
        while [ "$candidate" -ge 0 ] && [ "$candidate" -lt "$length" ]; do
            candidate_key="$(printf '%s\n' "$state_json" | jq -r --argjson cursor "$candidate" '.entries[$cursor]')"
            target="$(printf '%s\n' "$spaces_json" | jq -r --arg key "$candidate_key" '
                [.[] | select(.label == $key or ("id:" + (.id | tostring)) == $key)]
                | first | .index // empty
            ')"
            if [ -n "$target" ]; then
                updated="$(printf '%s\n' "$state_json" | jq -c --argjson cursor "$candidate" '.cursor = $cursor')"
                write_state "$updated"
                if ! yabai -m space --focus "$target" >/dev/null 2>&1; then
                    write_state "$state_json"
                fi
                exit 0
            fi
            candidate=$((candidate + step))
        done
        ;;
    *)
        printf 'usage: %s seed|record [space-index]|prev|next\n' "$0" >&2
        exit 2
        ;;
esac
