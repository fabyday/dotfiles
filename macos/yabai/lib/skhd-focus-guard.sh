#!/usr/bin/env sh
set -eu

SERVICE="com.koekeishiya.skhd"
UID_VALUE="$(id -u)"
DOMAIN="gui/$UID_VALUE"
TARGET="$DOMAIN/$SERVICE"
PLIST="$HOME/Library/LaunchAgents/$SERVICE.plist"
STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/yabai"
STATE_FILE="$STATE_DIR/skhd-focus-guard.state"
PAUSE_APPS_REGEX="${YABAI_SKHD_PAUSE_APPS_REGEX:-\\.exe$|^BDIH Launcher$}"
LOCK_FILE="${TMPDIR:-/tmp}/yabai-skhd-focus-guard.lock"

if [ "${1:-}" != "--locked" ]; then
    exec lockf -t 5 "$LOCK_FILE" sh "$0" --locked
fi

mkdir -p "$STATE_DIR"

is_skhd_running() {
    launchctl list 2>/dev/null |
        awk -v service="$SERVICE" '$3 == service && $1 ~ /^[0-9]+$/ { found = 1 } END { exit(found ? 0 : 1) }'
}

pause_skhd() {
    if ! is_skhd_running; then
        return
    fi

    launchctl bootout "$DOMAIN" "$PLIST" >/dev/null 2>&1 || true
    printf 'paused\n' > "$STATE_FILE"
    "$HOME/.config/sketchybar/lib/skhd_mode.sh" paused >/dev/null 2>&1 || true
}

resume_skhd() {
    if is_skhd_running; then
        if [ "$(cat "$STATE_FILE" 2>/dev/null || true)" = "paused" ]; then
            printf 'running\n' > "$STATE_FILE"
            "$HOME/.config/sketchybar/lib/skhd_mode.sh" normal >/dev/null 2>&1 || true
        fi
        return
    fi

    launchctl bootstrap "$DOMAIN" "$PLIST" >/dev/null 2>&1 || true
    launchctl kickstart -k "$TARGET" >/dev/null 2>&1 || true
    if is_skhd_running; then
        printf 'running\n' > "$STATE_FILE"
        "$HOME/.config/sketchybar/lib/skhd_mode.sh" normal >/dev/null 2>&1 || true
    fi
}

window_json="$(yabai -m query --windows --window 2>/dev/null || true)"

if [ -z "$window_json" ]; then
    resume_skhd
    exit 0
fi

display_index="$(printf '%s\n' "$window_json" | jq -r '.display // empty')"

if [ -z "$display_index" ]; then
    resume_skhd
    exit 0
fi

display_json="$(yabai -m query --displays 2>/dev/null |
    jq -c --argjson index "$display_index" '.[] | select(.index == $index)' || true)"

if [ -z "$display_json" ]; then
    resume_skhd
    exit 0
fi

if jq -e --argjson display "$display_json" --arg pause_apps "$PAUSE_APPS_REGEX" '
    def covers_display($win; $display):
        ($win.frame.w >= ($display.frame.w * 0.95)) and
        ($win.frame.h >= ($display.frame.h * 0.95)) and
        ($win.frame.x <= ($display.frame.x + 8)) and
        ($win.frame.y <= ($display.frame.y + 8)) and
        (($win.frame.x + $win.frame.w) >= ($display.frame.x + $display.frame.w - 8)) and
        (($win.frame.y + $win.frame.h) >= ($display.frame.y + $display.frame.h - 8));

    (.app // "" | test($pause_apps))
    and ."is-minimized" == false
    and ."is-hidden" == false
    and (
        ."is-native-fullscreen" == true
        or (
            ((."can-move" == false) or (."can-resize" == false))
            and covers_display(.; $display)
        )
    )
' >/dev/null 2>&1 <<EOF
$window_json
EOF
then
    pause_skhd
else
    resume_skhd
fi
