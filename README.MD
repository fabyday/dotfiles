# My dotfiles

## Includes
- Setup scripts for win/mac

- CPP (Win32/MacOS sinpets)
- CPP Project Generation Task(Template Project wasn't included)
- Zshrc files
- Neovim setup under `vim/nvim`
- macOS setup for zsh, yabai, skhd, and Hammerspoon

## macOS Setup

Detailed macOS setup notes are in `macos/README.md`.

The Neovim config is based on Lazy.nvim and inspired by:
https://github.com/ViegPhunt/Dotfiles/tree/main/.config/nvim

Install on macOS:

```sh
./MacSetup.sh
nvim
```

`MacSetup.sh` links:

- `vim/nvim` -> `~/.config/nvim`
- `macos/zsh/.zshrc` -> `~/.zshrc`
- `macos/yabai/.yabairc` -> `~/.yabairc`
- `macos/skhd/.skhdrc` -> `~/.skhdrc`
- `macos/sketchbar` -> `~/.config/sketchybar`
- `macos/hammerspoon` -> `~/.hammerspoon`

Existing files are moved to `*.backup.YYYYMMDDHHMMSS` before linking.
The first `nvim` launch bootstraps `lazy.nvim` and installs plugins.
