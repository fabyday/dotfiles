#!/usr/bin/env sh
set -eu

if [ "${1:-}" = "--on-app-switch" ]; then
    mode_file="${XDG_CACHE_HOME:-$HOME/.cache}/sketchybar/skhd-mode"
    case "$(cat "$mode_file" 2>/dev/null || true)" in
        normal|default|paused|stopped|'') exit 0 ;;
    esac
fi

skhd --reload
"$HOME/.config/sketchybar/lib/skhd_mode.sh" normal
