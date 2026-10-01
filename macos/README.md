# macOS Setup

This directory contains the macOS-specific dotfiles for zsh, yabai, skhd,
Hammerspoon, and related window-management helpers.

## Dependencies

Install Homebrew first:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Install the base tools:

```sh
brew install jq
brew install --cask hammerspoon
```

Install yabai/skhd. This setup currently uses the `asmvik/formulae` tap because
the installed binaries on this machine are `yabai-v7.1.17` and `skhd-v0.3.9`
from that tap:

```sh
brew tap asmvik/formulae
brew install asmvik/formulae/yabai
brew install asmvik/formulae/skhd
```

If Homebrew refuses the tap as untrusted, explicitly trust it first:

```sh
brew trust asmvik/formulae
```

Optional tools:

```sh
brew install borders
brew install sketchybar
brew install ripgrep
```

`borders` is used by `.yabairc` for active-window borders. `sketchybar` is used
for the thin bottom skhd mode indicator. `ripgrep` is useful for debugging but
is not required by the scripts.

## Link Dotfiles

From the repository root:

```sh
./MacSetup.sh
```

This links:

- `macos/zsh/.zshrc` -> `~/.zshrc`
- `macos/yabai` -> `~/.config/yabai`
- `macos/yabai/.yabairc` -> `~/.yabairc`
- `macos/skhd/.skhdrc` -> `~/.skhdrc`
- `macos/sketchbar` -> `~/.config/sketchybar`
- `macos/hammerspoon` -> `~/.hammerspoon`

Existing targets are moved to `*.backup.YYYYMMDDHHMMSS` before linking.

## Hammerspoon

Open Hammerspoon once from `/Applications`, then grant Accessibility permission:

```text
System Settings -> Privacy & Security -> Accessibility -> Hammerspoon
```

Reload the config from the Hammerspoon menu, or run:

```sh
hs -c 'hs.reload()'
```

If `hs` is not available, install the command-line tool from Hammerspoon:

```text
Hammerspoon -> Install Command Line Tool
```

The Hammerspoon config loads `stackline` and applies dynamic left padding only
when a real yabai stack exists.

## yabai

Grant Accessibility permission for yabai/skhd if macOS prompts for it:

```text
System Settings -> Privacy & Security -> Accessibility
```

Install and start the launch agent:

```sh
yabai --install-service
yabai --start-service
```

Reload the current config without restarting the service:

```sh
/bin/sh ~/.yabairc
```

Restart the service:

```sh
yabai --restart-service
```

Stop yabai:

```sh
yabai --stop-service
```

This config keeps the global layout as `bsp`. High-frequency automation that
moves windows, such as auto-stack, fit-windows, and state restore, is kept as
scripts but is not registered as live signals by default because it can create
layout feedback loops.

On startup, display changes, and wake, `yabai/ensure-display-spaces.sh` ensures
that every connected display has 10 Mission Control spaces. It also keeps the
global Mission Control index range deterministic: display 1 owns spaces 1-10,
display 2 owns spaces 11-20, display 3 owns spaces 21-30, and so on. Spaces are
labelled as `dNsM`, for example `d2s4` for display 2 slot 4.

## skhd

Install and start the launch agent:

```sh
skhd --install-service
skhd --start-service
```

If this tap is installed through Homebrew services, these direct commands are
also useful:

```sh
launchctl list | grep -i skhd
skhd --reload
```

Stop skhd:

```sh
skhd --stop-service
```

The current modal entry keys are:

- `cmd + alt - w`: window mode
- `cmd + alt - r`: resize mode
- `cmd + alt - i`: layout mode for BSP/stack reshaping
- `cmd + alt - d`: display/space mode
- `ctrl + alt - f`: focus the next floating window on the current space
- `ctrl + alt + shift - f`: focus the previous floating window on the current space

In display mode, pick a target display with `1`-`9`, then use `alt + 1`-`0` to
view that display's slot and `shift + alt + 1`-`0` to send the focused window to
that display's slot. For example, `cmd + alt + d`, `2`, `shift + alt + 4` sends
the focused window to display 2 slot 4 (`d2s4`, Mission Control space 14).

Layout mode has lightweight submodes:

- `w`: enter layout/warp mode
- `s`: enter layout/swap mode
- `a`: enter layout/stack mode
- `escape`: return to normal mode from layout, or back to layout from a submode

## SketchyBar

This repo uses SketchyBar as a thin bottom status strip. It does not replace the
macOS menu bar. The current setup shows the active skhd mode on the bottom right
and stable display/space groups on the left.

Start it with Homebrew services:

```sh
brew services start sketchybar
```

Reload the config:

```sh
sketchybar --reload ~/.config/sketchybar/sketchybarrc
```

The mode item is updated by:

```sh
~/.config/sketchybar/plugins/skhd_mode.sh normal
~/.config/sketchybar/plugins/skhd_mode.sh resize
~/.config/sketchybar/plugins/skhd_mode.sh layout
~/.config/sketchybar/plugins/skhd_mode.sh layout_warp
~/.config/sketchybar/plugins/skhd_mode.sh layout_swap
~/.config/sketchybar/plugins/skhd_mode.sh layout_stack
~/.config/sketchybar/plugins/skhd_mode.sh window
~/.config/sketchybar/plugins/skhd_mode.sh display
```

Spaces are updated without reloading the whole bar:

```sh
~/.config/sketchybar/plugins/update_spaces.sh
sketchybar --trigger yabai_spaces_changed
```

## Fullscreen Focus Guard

`macos/yabai/skhd-focus-guard.sh` is registered through yabai signals:

- `window_focused`
- `space_changed`

When the focused window is native fullscreen, or when it is a borderless
fullscreen-style window that cannot be moved or resized, the script stops skhd.
When focus returns to a normal window, it starts skhd again.

This is meant to prevent global skhd hotkeys from interfering with fullscreen
games and other exclusive-style windows.

## Emergency Stop

If the window manager starts behaving badly or consumes too much CPU:

```sh
uid="$(id -u)"
launchctl bootout "gui/$uid" "$HOME/Library/LaunchAgents/homebrew.mxcl.skhd.plist" 2>/dev/null || true
launchctl bootout "gui/$uid" "$HOME/Library/LaunchAgents/com.asmvik.yabai.plist" 2>/dev/null || true
pkill -x skhd 2>/dev/null || true
pkill -x yabai 2>/dev/null || true
pkill -x borders 2>/dev/null || true
```

Check what is still running:

```sh
pgrep -fl '(^|/)(skhd|yabai|borders)( |$)'
launchctl list | grep -Ei 'skhd|yabai'
```

## File Map

- `zsh/.zshrc`: shell config
- `yabai/.yabairc`: main yabai config
- `yabai/skhd-focus-guard.sh`: pauses skhd while fullscreen-like windows are focused
- `yabai/ensure-display-spaces.sh`: keeps display N mapped to spaces `(N-1)*10+1` through `N*10`
- `yabai/display-space.sh`: maps slot 1-10 to spaces on the selected target display
- `yabai/auto-stack-window.sh`: manual/experimental helper for stacking new windows
- `yabai/fit-windows.sh`: manual/experimental helper for fitting windows into displays
- `yabai/state.sh`, `yabai/refresh.sh`, `yabai/reload.sh`: manual/experimental state helpers
- `skhd/.skhdrc`: modal hotkey config
- `sketchbar/sketchybarrc`: thin bottom SketchyBar config
- `sketchbar/plugins/skhd_mode.sh`: updates the skhd mode indicator
- `hammerspoon/init.lua`: Hammerspoon entrypoint
- `hammerspoon/stackline`: stack indicator module
