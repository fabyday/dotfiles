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
brew install python
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
- `macos/skhd` -> `~/.config/skhd`
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

This config keeps the global layout as `bsp`. New windows without a matching
yabai rule are stacked through a serialized `window_created` handler. Windows
matching a rule are left alone so their rule can move them without triggering a
repeated layout change. Windows already present before the signal is registered
are not retroactively stacked.

On startup, display changes, and wake, `yabai/lib/ensure-display-spaces.sh` ensures
that every connected display has 10 Mission Control spaces. Labels such as
`d2s4` identify display 2 slot 4 even when macOS changes space indexes. When a
display disconnects, its labelled spaces may move to another display; they are
returned to their labelled display when it reconnects.


### checking help script command
- find app name on yabai
        ```bash
        yabai -m query --windows | jq -r '.[] | [.app, .title] | @tsv'
        ```


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
~/.config/skhd/lib/reload.sh
```

The helper reloads skhd and resets the mode indicator to Normal. The
SketchyBar watcher also resets it when skhd hotloads an edited config.
Switching to another app also returns skhd to Normal mode.

Stop skhd:

```sh
skhd --stop-service
```

The current modal entry keys are:

- `cmd + alt - u`: window mode
- `cmd + alt - i`: resize mode
- `cmd + alt - o`: relocate mode for BSP insertion/stacking
- `cmd + alt - p`: display/space mode

New windows default to stacking onto the previously focused window in the same
space after any yabai space rule has settled. In Relocate mode, `shift + s` selects
STACK for new windows and `shift + b` selects BSP tiling. The selection is
saved across restarts. SketchyBar shows `NEW STACK` or `NEW BSP` immediately to
the left of the skhd mode indicator.

In display mode, `h`/`l` select the previous/next connected display. `j`/`k`
move backward/forward through that display's workspace history. Each display
keeps its own last 10 visits, including repeated visits to the same space.
For example, after `1 → 3 → 4 → 2 → 1`, going back to `4` and choosing `5`
changes the history to `1 → 3 → 4 → 5`. `1`-`0` focus slots 1-10 on the selected
display, and `shift + 1`-`0` move the focused window there. `shift + h`/`l`
move the window to the previous/next display. If a display disconnects, the
selection falls back to the remaining display. `escape` returns to normal mode,
and `cmd + alt + escape`
resets the mode from any state. `cmd + alt + p` also exits display mode. The
mode indicator shows `PAUSED` while the fullscreen focus guard has stopped skhd.
In Display mode, `alt + 1` through `alt + 6` send the focused window directly to
that display's active space and focus it. A missing display is ignored.

In relocate mode, `h`/`j`/`k`/`l` stack the focused window onto a neighbor,
while their shifted versions mark the focused window as the next BSP insertion
target in that direction. The red region previews where the next window will
be inserted; selecting a direction does not move a window by itself. Press the
same shifted direction again on the same window to clear the preview, or insert
another window there to use it. `escape` returns to normal skhd mode but does
not clear yabai's insertion target.
`cmd + shift + w`/`e` cycle through a stack in every skhd mode.
In Window mode, `2`, `3`, `5`, `7`, and `8` set the top BSP split to 20/80,
30/70, 50/50, 70/30, and 80/20. The first percentage belongs to the root
tree's first (left or top) child. `0` still balances every split in the space.

## SketchyBar

This repo uses SketchyBar as a thin bottom status strip. It does not replace the
macOS menu bar. The current setup shows the active skhd mode on the bottom right
and display/space groups on the left. Each connected display shows only its own
group. If a display disconnects, occupied spaces from its group appear on the
display currently hosting them; the group returns when the display reconnects.

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
~/.config/sketchybar/lib/skhd_mode.sh normal
~/.config/sketchybar/lib/skhd_mode.sh resize
~/.config/sketchybar/lib/skhd_mode.sh relocate
~/.config/sketchybar/lib/skhd_mode.sh window
~/.config/sketchybar/lib/skhd_mode.sh display
~/.config/sketchybar/lib/skhd_mode.sh paused
```

Spaces are updated without reloading the whole bar:

```sh
~/.config/sketchybar/lib/update_spaces.sh
sketchybar --trigger yabai_spaces_changed
```

## Fullscreen Focus Guard

`macos/yabai/lib/skhd-focus-guard.sh` is registered through yabai signals:

- `window_focused`
- `space_changed`

For apps matching `YABAI_SKHD_PAUSE_APPS_REGEX` (by default `.exe` apps and
`BDIH Launcher`), the script stops skhd while the focused window is native
fullscreen or a borderless fullscreen-style window. It starts skhd again when
focus returns to another window. Fullscreen Code windows keep the hotkeys active.

This is meant to prevent global skhd hotkeys from interfering with fullscreen
games and other exclusive-style windows.

## Emergency Stop

If the window manager starts behaving badly or consumes too much CPU:

```sh
uid="$(id -u)"
launchctl bootout "gui/$uid" "$HOME/Library/LaunchAgents/com.koekeishiya.skhd.plist" 2>/dev/null || true
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

Keep each component's helper `.sh` files in its `lib/` directory. The `skhd`
directory currently contains only its main config; its bindings call helpers
from the `yabai/lib` and `sketchbar/lib` directories.

- `zsh/.zshrc`: shell config
- `yabai/.yabairc`: main yabai config
- `yabai/lib/skhd-focus-guard.sh`: pauses skhd while fullscreen-like windows are focused
- `yabai/lib/ensure-display-spaces.sh`: maintains labelled spaces and returns them after reconnect
- `yabai/lib/display-space.sh`: maps slot 1-10 to spaces on the selected target display
- `yabai/lib/space-history.sh`: keeps ten workspace visits per display
- `yabai/lib/auto-stack-window.sh`: stacks new windows without matching rules
- `yabai/lib/fit-windows.sh`: manual/experimental helper for fitting windows into displays
- `yabai/lib/state.sh`, `yabai/lib/refresh.sh`, `yabai/lib/reload.sh`: manual/experimental state helpers
- `skhd/.skhdrc`: modal hotkey config
- `sketchbar/sketchybarrc`: thin bottom SketchyBar config
- `sketchbar/lib/skhd_mode.sh`: updates the skhd mode indicator
- `sketchbar/lib/skhd_mode_watch.sh`: resets the indicator after skhd restarts
- `hammerspoon/init.lua`: Hammerspoon entrypoint
- `hammerspoon/stackline`: stack indicator module
