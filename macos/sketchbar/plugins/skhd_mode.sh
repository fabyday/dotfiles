#!/usr/bin/env sh

mode="${1:-normal}"
state_dir="${XDG_CACHE_HOME:-$HOME/.cache}/sketchybar"
state_file="$state_dir/skhd-mode"

mkdir -p "$state_dir"
printf '%s\n' "$mode" > "$state_file"

if ! command -v sketchybar >/dev/null 2>&1; then
    exit 0
fi

case "$mode" in
    normal|default)
        label="NORMAL"
        color="0xff9ca3af"
        background="0x551f2937"
        ;;
    window)
        label="WINDOW"
        color="0xff93c5fd"
        background="0x553b82f6"
        ;;
    resize)
        label="RESIZE"
        color="0xfffcd34d"
        background="0x557c2d12"
        ;;
    layout)
        label="LAYOUT"
        color="0xff86efac"
        background="0x55166534"
        ;;
    layout_warp)
        label="LAYOUT/WARP"
        color="0xff67e8f9"
        background="0x55164e63"
        ;;
    layout_swap)
        label="LAYOUT/SWAP"
        color="0xfff9a8d4"
        background="0x55531237"
        ;;
    layout_stack)
        label="LAYOUT/STACK"
        color="0xffc4b5fd"
        background="0x554c1d95"
        ;;
    display)
        label="DISPLAY"
        color="0xfffdba74"
        background="0x557c2d12"
        ;;
    *)
        label="$(printf '%s' "$mode" | tr '[:lower:]' '[:upper:]')"
        color="0xffe5e7eb"
        background="0x55374151"
        ;;
esac

sketchybar --set skhd.mode \
    label="$label" \
    icon.color="$color" \
    label.color="$color" \
    background.color="$background" >/dev/null 2>&1 || true
