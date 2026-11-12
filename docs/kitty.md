# Kitty

The Kitty terminal includes a custom Python status bar (`tab_bar.py`) rendered at the bottom alongside tabs. It refreshes every 5 seconds and shows:

`󰟀 hostname  󰍛 cpu%  freq  󰍺 ram%  used/total  󰔏 CPU°C  GPU°C  󰤨 ↓speed ↑speed  dBm  󰁹 bat%  󰃭 date  󰥔 time`

The status bar is adaptive — lower-priority segments (hostname, CPU frequency, temperatures, date) are dropped first when tabs fill the bar.

**Fonts** — FiraCode Nerd Font Mono with three of Fira's alternates: `ss08` keeps `==` as two signs, `ss02` draws `<=` `>=` as flat ≤ ≥, and `ss03` a plain `&`. Fira Code has no italics, so italic text (the comments of every colour scheme here) is Maple Mono NL's cursive. NL is the build without ligatures, so a comment never draws `==` or `<=` differently from the code beside it. Icons come from FiraCode Nerd Font's own glyphs.

**Cursor and display** — `cursor_trail` animates the cursor's jumps in every program, Neovim included. kitty picks X11 or Wayland to match the session; under GNOME Wayland, the only session Ubuntu 26.04 has, its title bar takes the window's background colour.

**Key bindings**

| Key | Action |
|---|---|
| `F2` | Open Neovim in current directory |
| `F3` | Save the current layout as a session |
| `F4` | Browse saved sessions and switch to one |
| `F5` | Back to the previously active session |
| `Ctrl+0` | Back to the previously active tab |
| `Ctrl+Shift+M` | Zoom the current split to the whole tab and back |
| `Ctrl+Shift+G` | Lazygit over the current window, in its directory |
| `Alt+Arrows` | Move to the split in that direction |
| `Alt+Shift+Arrows` | Swap the current split with its neighbour that way |
| `Ctrl+Shift+Y` | Copy the last command's output straight to the clipboard |
| `Ctrl+Shift+Enter` | New split in `$HOME`, a local shell even from an ssh session |
| `Ctrl+Alt+Enter` | New split in the current directory; from an ssh session, another connection to the same host |
| `Ctrl+Shift+T` | New tab in the current directory |
| `Ctrl+Shift+F5` | Reload config |

**Sessions**

`F3` writes the live layout — OS windows, tabs, splits, working directories and
the programs running in them — to a file under
`~/.local/share/kitty/sessions`, then opens it in `$EDITOR` to review. `F4`
lists what's there and switches to one.

Two flags carry the weight. `--use-foreground-process` is what records `nvim`,
`lazygit` or a `tail -f`; without it every pane comes back as a bare shell.
`--base-dir` pins the output directory, because kitty launched from a desktop
shortcut does not start in `$HOME` and the save prompt would otherwise default
to whatever that happened to be.

`Ctrl+Alt+Enter` (`new_window_with_cwd`) is the companion: windows created
that way join the active session rather than falling outside it.

This layers with the [Neovim sessions](neovim.md) rather than duplicating them — kitty
restores the terminal layout and relaunches `nvim` in the right directory,
`<leader>qs` then restores the buffers and splits inside it.

Session files can also be written by hand (`layout tall`, `cd …`,
`launch --title "Build" …`) and loaded with `kitty --session <file>`, or set as
`startup_session` in `kitty.conf`. `save_as_session` is also ssh-kitten aware:
it records the remote working directory and running program.
