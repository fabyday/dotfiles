#!/usr/bin/env sh
set -eu

LOCK_DIR="${TMPDIR:-/tmp}/yabai-fit-windows.lock"

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    exit 0
fi

trap 'rmdir "$LOCK_DIR"' EXIT INT TERM

sleep "${YABAI_FIT_DELAY:-0.3}"

DISPLAY_JSON="$(yabai -m query --displays)"
WINDOW_JSON="$(yabai -m query --windows)"

window_overflows_filter='
    def display_for($idx): $displays[] | select(.index == $idx);
    . as $win
    | display_for($win.display) as $display
    | (
        ($win.frame.x < $display.frame.x) or
        ($win.frame.y < $display.frame.y) or
        (($win.frame.x + $win.frame.w) > ($display.frame.x + $display.frame.w)) or
        (($win.frame.y + $win.frame.h) > ($display.frame.y + $display.frame.h))
      )
'

overflowing_managed_spaces() {
    printf '%s\n' "$WINDOW_JSON" |
        jq -r --argjson displays "$DISPLAY_JSON" '
            .[]
            | select(."is-minimized" == false)
            | select(."is-hidden" == false)
            | select(."is-floating" == false)
            | select(."can-resize" == true)
            | select('"$window_overflows_filter"')
            | .space
        ' | sort -nu
}

fit_floating_windows() {
    printf '%s\n' "$WINDOW_JSON" |
        jq -r --argjson displays "$DISPLAY_JSON" '
            def display_for($idx): $displays[] | select(.index == $idx);
            .[]
            | select(."is-minimized" == false)
            | select(."is-hidden" == false)
            | select(."is-floating" == true)
            | select(."can-move" == true)
            | select(."can-resize" == true)
            | . as $win
            | display_for($win.display) as $display
            | ($display.frame.x | floor) as $dx
            | ($display.frame.y | floor) as $dy
            | ($display.frame.w | floor) as $dw
            | ($display.frame.h | floor) as $dh
            | ($win.frame.w | floor) as $ww
            | ($win.frame.h | floor) as $wh
            | ([($ww), ($dw)] | min) as $nw
            | ([($wh), ($dh)] | min) as $nh
            | ([([$win.frame.x | floor, $dx] | max), ($dx + $dw - $nw)] | min) as $nx
            | ([([$win.frame.y | floor, $dy] | max), ($dy + $dh - $nh)] | min) as $ny
            | select(
                ($win.frame.x < $dx) or
                ($win.frame.y < $dy) or
                (($win.frame.x + $win.frame.w) > ($dx + $dw)) or
                (($win.frame.y + $win.frame.h) > ($dy + $dh))
              )
            | [.id, $nx, $ny, $nw, $nh] | @tsv
        ' |
    while IFS="$(printf '\t')" read -r id x y w h; do
        [ -n "$id" ] || continue
        yabai -m window "$id" --move "abs:$x:$y" >/dev/null 2>&1 || true
        yabai -m window "$id" --resize "abs:$w:$h" >/dev/null 2>&1 || true
    done
}

fit_floating_windows

overflowing_managed_spaces |
while IFS= read -r space; do
    [ -n "$space" ] || continue
    yabai -m space "$space" --balance >/dev/null 2>&1 || true
done

# If a managed window still cannot fit after balancing, stack it onto another
# managed window in the same space. This avoids off-screen windows when an app
# has a large minimum size.
DISPLAY_JSON="$(yabai -m query --displays)"
WINDOW_JSON="$(yabai -m query --windows)"

printf '%s\n' "$WINDOW_JSON" |
    jq -r --argjson displays "$DISPLAY_JSON" '
        . as $windows
        | .[]
        | select(."is-minimized" == false)
        | select(."is-hidden" == false)
        | select(."is-floating" == false)
        | select(."can-move" == true)
        | select(."can-resize" == true)
        | select(."stack-index" == 0)
        | select('"$window_overflows_filter"')
        | . as $win
        | (
            $windows
            | map(select(.space == $win.space))
            | map(select(.display == $win.display))
            | map(select(.id != $win.id))
            | map(select(."is-floating" == false))
            | map(select(."can-move" == true))
            | map(select(."is-minimized" == false))
            | map(select(."is-hidden" == false))
            | sort_by(.frame.w * .frame.h)
            | reverse
            | first
          ) as $anchor
        | select($anchor.id != null)
        | [$anchor.id, $win.id] | @tsv
    ' |
while IFS="$(printf '\t')" read -r anchor overflow; do
    [ -n "$anchor" ] || continue
    [ -n "$overflow" ] || continue
    yabai -m window "$anchor" --stack "$overflow" >/dev/null 2>&1 || true
done
