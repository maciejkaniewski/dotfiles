# Kitty

The Kitty terminal includes a custom Python status bar (`tab_bar.py`) rendered at the bottom alongside tabs. It refreshes every 5 seconds and shows:

`󰟀 hostname  󰍛 cpu%  freq  󰍺 ram%  used/total  󰔏 CPU°C  GPU°C  󰤨 ↓speed ↑speed  dBm  󰁹 bat%  󰃭 date  󰥔 time`

The status bar is adaptive — lower-priority segments (hostname, CPU frequency, temperatures, date) are dropped first when tabs fill the bar.

Under [niri](niri.md), Waybar shows the system readouts, so the bar drops them and keeps only the host and IP: the one thing Waybar can't know, since it follows the active window into ssh sessions.

**Fonts** — FiraCode Nerd Font Mono with three of Fira's alternates: `ss08` keeps `==` as two signs, `ss02` draws `<=` `>=` as flat ≤ ≥, and `ss03` a plain `&`. Fira Code has no italics, so italic text (the comments of every colour scheme here) is Maple Mono NL's cursive. NL is the build without ligatures, so a comment never draws `==` or `<=` differently from the code beside it. Icons come from FiraCode Nerd Font's own glyphs.

**Cursor and display** — `cursor_trail` animates the cursor's jumps in every program, Neovim included. kitty picks X11 or Wayland to match the session; under GNOME Wayland, the only session Ubuntu 26.04 has, its title bar takes the window's background colour.

**Key bindings**

| Key | Action |
|---|---|
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
