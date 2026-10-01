#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_SUFFIX="$(date +%Y%m%d%H%M%S)"

link_path() {
    local source="$1"
    local target="$2"
    local target_dir

    target_dir="$(dirname "$target")"
    mkdir -p "$target_dir"

    if [ -e "$target" ] || [ -L "$target" ]; then
        if [ "$(readlink "$target" 2>/dev/null || true)" = "$source" ]; then
            echo "Already linked $target -> $source"
            return
        fi

        local backup="$target.backup.$BACKUP_SUFFIX"
        mv "$target" "$backup"
        echo "Backed up existing $target to $backup"
    fi

    ln -s "$source" "$target"
    echo "Linked $target -> $source"
}

link_path "$DOTFILES_DIR/vim/nvim" "$HOME/.config/nvim"
link_path "$DOTFILES_DIR/macos/yabai" "$HOME/.config/yabai"
link_path "$DOTFILES_DIR/macos/sketchbar" "$HOME/.config/sketchybar"
link_path "$DOTFILES_DIR/macos/hammerspoon" "$HOME/.hammerspoon"
link_path "$DOTFILES_DIR/macos/zsh/.zshrc" "$HOME/.zshrc"
link_path "$DOTFILES_DIR/macos/yabai/.yabairc" "$HOME/.yabairc"
link_path "$DOTFILES_DIR/macos/skhd/.skhdrc" "$HOME/.skhdrc"

if command -v nvim >/dev/null 2>&1; then
    echo "Run 'nvim' to let lazy.nvim install plugins."
else
    echo "Neovim is not installed. Install it first, then run 'nvim'."
fi
