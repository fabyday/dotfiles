#!/usr/bin/env sh
set -eu

STATE_SCRIPT="${HOME}/.config/yabai/state.sh"
MODE="${1:-restore}"
LOCK_DIR="${TMPDIR:-/tmp}/yabai-refresh-${MODE}.lock"

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    exit 0
fi

trap 'rmdir "$LOCK_DIR"' EXIT INT TERM

case "$MODE" in
    save)
        sleep 0.2
        ;;
    restore)
        # Let macOS/yabai finish publishing display and window changes before restoring.
        sleep 0.8
        displays="$(yabai -m query --displays 2>/dev/null || printf '[]')"
        if yabai -m query --windows 2>/dev/null |
            jq -e --argjson displays "$displays" '
                def display_for($idx): $displays[] | select(.index == $idx);
                def covers_display($win; $display):
                    ($win.frame.w >= ($display.frame.w * 0.95)) and
                    ($win.frame.h >= ($display.frame.h * 0.95)) and
                    ($win.frame.x <= ($display.frame.x + 8)) and
                    ($win.frame.y <= ($display.frame.y + 8)) and
                    (($win.frame.x + $win.frame.w) >= ($display.frame.x + $display.frame.w - 8)) and
                    (($win.frame.y + $win.frame.h) >= ($display.frame.y + $display.frame.h - 8));
                any(.[]; . as $win
                    | ."is-minimized" == false
                    | . and ."is-hidden" == false
                    | . and (display_for($win.display) as $display
                        | $win."is-native-fullscreen" == true
                          or (((($win."can-move" == false) or ($win."can-resize" == false))
                              and covers_display($win; $display))))
                )
            ' >/dev/null 2>&1; then
            exit 0
        fi
        ;;
    *)
        exit 2
        ;;
esac

if [ -x "$STATE_SCRIPT" ]; then
    "$STATE_SCRIPT" "$MODE" >/dev/null 2>&1 || true
fi
