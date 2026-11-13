# niri

[niri](https://github.com/niri-wm/niri) is a scrollable-tiling Wayland compositor. Every window opens as a full-height column on a strip that scrolls sideways, so opening a window never shrinks the others. Each monitor has its own strip, and workspaces stack vertically on it, with an empty one always at the end.

It is opt-in and sits beside GNOME rather than replacing it: `./install.sh --setup` asks whether to add it (default no), and `./install.sh --niri` adds it later. Either way you get a **niri** entry in the gear menu on the login screen, and GNOME stays one logout away.

## Install

Answer yes when `./install.sh --setup` asks, or, on a machine that's already set up:

```bash
./install.sh --niri
```

- **Built from source, at the versions in [`versions`](../versions):** niri, xwayland-satellite (runs X11 apps) and Waybar. Ubuntu 24.04 packages none of the first two, and its Waybar 0.9.24 predates the niri modules; 26.04 has Waybar 0.15 but still no niri, and the same apt packages under the same names. The builds need Rust and take about 15 minutes the first time; niri's binary is installed stripped (about 26 MB rather than 133). Once niri is installed, `--setup` rebuilds only when a pin moves.
- **From apt:** fuzzel (launcher), mako (notifications), swaylock and swayidle (lock and idle), swaybg (wallpaper), the GNOME polkit agent (password prompts), playerctl (media keys), and the build dependencies.
- **Configs:** `.config/niri/config.kdl` and Waybar's config and stylesheet are symlinked, and `~/.config/niri/local.kdl` is written with this machine's keyboard layout.
- **Wallpapers:** the community wallpapers listed in `.config/niri/wallpapers/sources` (by repo, pinned commit and path) are downloaded and blurred with Pillow into `~/.local/share/wallpapers/{family}/`, about 3 MB in all. Only the list is in this repo, since the images are other people's work under their collections' terms. `wallpaper --fetch` does it again, skipping ones already there.

Then log out, pick niri from the gear on the login screen, and press `Super+Shift+/` for the list of key bindings.

## What runs in the session

| Part | Tool |
|---|---|
| Bar | Waybar, as rounded islands. The **main screen** gets the full bar: workspaces (with an icon per window), what's playing, the clock, system readouts (CPU, memory, disk, temperature, serial adapters), the tray and controls (keep-awake, Bluetooth, volume, power mode, battery, power menu). The **other screens** get a slim bar with their workspaces as dots and the clock. `Super+Shift+B` makes the focused screen the main one, remembered by make, model and serial in the machine-local `~/.config/waybar/main-output`; when that screen isn't connected, the laptop's takes over. `.local/bin/waybar-launch` runs Waybar this way and restarts it when screens come or go. Hovering over the clock shows the month (weeks from Monday, weekends in red) |
| Launcher | fuzzel (`Super+D`) |
| Notifications | mako |
| Network | nm-applet's Wi-Fi icon in Waybar's tray: its menu lists Wi-Fi networks and VPNs. The session's XDG autostart starts it, as GNOME's does |
| Power mode | Waybar's power-mode icon (GNOME's power-saver, balanced and performance, from power-profiles-daemon): click for the next mode, right-click for the previous one |
| Sound | Waybar's volume; clicking opens pulsemixer in a floating kitty (per-app volume, devices), right-click mutes |
| Bluetooth | Waybar's Bluetooth icon (hover for connected devices); clicking opens [bluetui](https://github.com/pythops/bluetui) in a floating kitty for pairing and connecting |
| Lock and idle | `.local/bin/lock-screen`: swaylock-effects (built from source, patched by `patches/swaylock-effects/second-time-zone.patch`) over the theme's wallpaper, with the time and date in the ring and, under them, the first zone of `~/.config/waybar/timezones` ("10:45 EST", the time only); plain swaylock over the wallpaper if swaylock-effects is missing. A blurred community wallpaper is a JPEG and loads at once; for a glow SVG, which swaylock takes about a second to draw, it uses a PNG of it kept in `~/.cache/lock-screen`. Either way it appears at once, within a tenth of a second, with no fade. |
| Media | Waybar shows what's playing (Spotify, a browser tab: anything that speaks MPRIS) and hides when nothing is. Click to play or pause, right-click or scroll for the next track, middle-click for the previous. Waybar is built with libplayerctl for this |
| Disk and network | Waybar shows how full `/` is; hover for free space and the current download and upload speed of whichever interface has the default route (`.local/bin/waybar-io`) |
| Power menu | `.local/bin/power-menu`: lock, suspend, log out, reboot or shut down, picked in fuzzel |
| Clipboard history | cliphist stores what you copy, text and images |
| Volume and brightness | The keys go through `.local/bin/osd`, which changes the level and shows it as a pop-up with a progress bar that replaces itself rather than stacking |
| Battery | `.local/bin/battery-notify` warns at 15% and urgently at 5% while discharging, and switches to power-saver at 20% (back to the previous mode on the charger), as GNOME does |
| Serial ports | `ports --notify` sends a notification whenever a USB serial adapter is plugged in or out, and Waybar shows how many are plugged in (`ports --waybar`, updated on each plug rather than polled): hover lists them, click opens `ports -w` |
| Notifications | mako, with app icons, one stacked notification per app (with a count), and urgent ones kept until dismissed. `Super+N` brings back the last one, `Super+Shift+N` dismisses all |
| Clipboard for X11 tools | `.local/bin/xclip` answers xclip from the Wayland clipboard in a Wayland session. xwayland-satellite's X11 copy can lag, and tools that try xclip first (Claude Code's image paste) pasted a stale screenshot |
| Night light | wlsunset: warmer colours from 20:00 to 06:00 (change the times in `config.kdl`) |
| Wallpaper | swaybg. By default the theme's own glow, `.config/niri/wallpapers/{variant}.svg` (its dark tones with soft glows of its accents). `Super+Alt+W` cycles on through its family's community wallpapers ([Catppuccin](https://github.com/zhichaoh/catppuccin-wallpapers), [Dracula](https://github.com/dracula/wallpaper), [Gruvbox](https://github.com/AngelJumbo/gruvbox-wallpapers)), blurred and dimmed into soft fields of their colours to match the glow (`.local/bin/wallpaper`). Switching between variants of a family keeps the one you picked; switching family goes back to the glow |
| Files | Thunar, set as the app for folders (`xdg-open .`, `o`), instead of GNOME Files, which waits on GNOME's Tracker indexer and stays tied to the terminal. yazi (`Super+E`, `y`) for the terminal |
| Settings | GNOME's Settings app (`Super+,`) for Wi-Fi, Bluetooth and sound; monitors are set in `local.kdl` instead |
| X11 apps | xwayland-satellite, which niri starts by itself when the first X11 app connects |
| Screen sharing | xdg-desktop-portal-gnome, so call apps can share one window or a whole screen. A shared window gets a red border; for a shared screen, and while anything records it, Waybar shows a red "sharing" pill by the clock on every screen (`.local/bin/waybar-cast`, from niri's list of screencasts) |

**VS Code** picks its password store by recognising the desktop, and doesn't know niri. `--niri` therefore sets `"password-store": "gnome-libsecret"` in `~/.vscode/argv.json`, the same keyring VS Code uses under GNOME.

**No duplicated status bar.** Waybar shows the readouts kitty's tab bar shows under GNOME, in the same colours. Under niri, kitty's bar drops them and keeps only the host and IP of the active window, which follow it into ssh sessions. kitty checks for niri through `NIRI_SOCKET`, so the same `tab_bar.py` serves both sessions.

## Key bindings

`Super` is the modifier for everything, so nothing clashes with kitty's `Alt` bindings for moving between its splits.

| Key | Action |
|---|---|
| `Super+T` or `Super+Enter` | kitty |
| `Super+D` | Launcher |
| `Super+E` | yazi in kitty |
| `Super+Q` | Close the window |
| `Super+Shift+Q` | Close every window on this workspace (apps can still ask to save); the empty workspace then goes |
| `Super+←/→` or `Super+H/L` | Focus the column to the left or right |
| `Super+↑/↓` or `Super+K/J` | Focus the window above or below in the column |
| `Super+Ctrl+` direction | Move the column or window |
| `Super+Shift+` direction | Focus the monitor that way |
| `Super+Shift+Ctrl+` direction | Move the column to the monitor that way |
| `Super+Alt+` arrow | Move the whole workspace to the monitor that way |
| `Super+1`…`9`, `Super+U/I` | Go to a workspace, or the one below or above |
| `Super+Ctrl+1`…`9` | Move the column to a workspace |
| `Super+R` | Cycle the column width: a third, a half, two thirds |
| `Super+F` / `Super+Shift+F` | Maximise the column / fullscreen the window, which covers the bar too |
| `Super+B` | Hide or show the bar; windows take the space |
| `Super+Shift+B` | Make the focused screen the main one, with the full bar |
| `Super+C` | Centre the column |
| `Super+-` / `Super+=` | Narrow or widen the column by 10% |
| `Super+[` / `Super+]` | Pull a window into the neighbouring column, or push it out into its own |
| `Super+W` | Show the column as tabs |
| `Super+V` | Float the window, or tile it again |
| `Super+O` | Overview of every workspace |
| `Print`, `Ctrl+Print`, `Alt+Print` | Screenshot a region, the screen, the window (saved to `~/Pictures/Screenshots` and copied) |
| `Super+Alt+L` | Lock the screen |
| `Super+Alt+W` | Next wallpaper |
| `Ctrl+Alt+Delete` | Power menu |
| `Super+Shift+C` | Clipboard history: pick an entry to copy it back, then paste with `Ctrl+V` |
| `Super+,` | GNOME Settings |
| `Alt+Tab`, ``Alt+` `` | Switch to a recent window, or between windows of the same app, with previews (also `Super+Tab`). Keep holding `Alt` and press `Tab` again to go further back; in the switcher, `W`, `O` and `A` narrow it to this workspace, this screen or everything |
| `Super+Escape` | Let a VM or remote desktop have the keyboard shortcuts |
| `Super+Shift+E` | Log out |
| `Super+N` / `Super+Shift+N` | Bring back the last notification / dismiss all |
| `Super+Shift+/` | Show every binding |

The volume, brightness and media keys work as usual, also on the lock screen.

## Look

- The focused window has a gradient focus ring (the theme's accent into its second colour) and a soft glow in the accent colour. Windows you're not in fade slightly (92% opacity).
- Floating windows cast a deeper drop shadow and blur what's behind them, so they read as lifted above the tiles.
- A window shared in a call has a red border for as long as it's shared.
- The wallpaper sits in the overview's backdrop, so in `Super+O` the workspaces float over it; workspaces themselves are transparent, so it shows behind windows as usual.
- GTK apps use the Yaru accent closest to the theme (purple, or olive for Gruvbox) and Papirus icons. Both are GNOME-wide settings that `--theme` sets, so GNOME follows too.
- Waybar's workspace buttons show an icon per window on them (kitty, VS Code, Slack, browsers, Thunar; a plain window icon for others). The side screens' bars show a dot per workspace instead, filled for the one on screen.
- Waybar sits on the bottom layer, so in the overview (`Super+O`) it zooms out with each workspace instead of staying full size on top. Tiled windows still leave its space free.
- Animations run a little faster than niri's defaults, and window moves end with a slight spring (`animations` in `config.kdl`).

## Window rules

- Browsers open at two thirds of the screen width.
- Slack, Thunderbird and Teams open on workspace 1. A rule can only target a named workspace, so workspace 1 is one, named "1": niri puts named workspaces first and keeps them even when empty, so the numbering stays 1, 2, 3 and `Super+1` reaches it.
- Calculator, Settings, Calendar, the network connection editor and `nmtui` float.
- A workspace's only window sits in the middle of the screen.
- Dialogs float on their own. Angry IP Scanner's (Java, through X11) float at a minimum of 460×340, since they otherwise open far too small for their contents.
- Clicking a tray icon or notification of Slack, Discord or Telegram brings its window forward (`honor-xdg-activation-with-invalid-serial`), and only the focused window counts as active, so Electron apps (Slack, Teams, VS Code) don't hold back notifications (`deactivate-unfocused-windows`). Both are niri debug options, which may change between releases.

## Themes

The theme picker covers niri too. `./install.sh --theme` links one `{variant}` file for each tool:

| Link | Points at |
|---|---|
| `~/.config/niri/theme.kdl` | `.config/niri/{variant}.kdl`: focus ring, shadow, overview backdrop, the Alt+Tab highlight, the shared window's border |
| `~/.config/waybar/theme.css` | `.config/waybar/{variant}.css`: the colours `style.css` uses |
| `~/.config/fuzzel/fuzzel.ini` | `.config/fuzzel/{variant}.ini` |
| `~/.config/mako/config` | `.config/mako/{variant}.conf` |
| `~/.config/swaylock/config` | `.config/swaylock/{variant}.conf` |

fuzzel, mako and swaylock have no include, so each of their theme files is a whole config. A theme switch reaches a running session straight away: niri reloads its includes, and the picker signals Waybar and mako to reload. These links are made only on machines where `--niri` installed niri.

## This machine's settings

`config.kdl` ends by including `~/.config/niri/local.kdl` when it exists. That file is untracked, so it holds what differs per machine:

- **Keyboard layout:** `--niri` copies GNOME's first input source when it creates the file, and never overwrites it afterwards.
- **Monitors:** `niri msg outputs` lists the connected ones. Add an `output` block for each, with its scale and position. Docked monitors are best matched by make, model and serial (`output "Dell Inc. DELL U2723QE ABC1234" { … }`), since connector names like `DP-6` can change between dock ports. niri applies a block whenever that monitor is plugged in, so docking and undocking need no extra tool.
- **Main bar's screen:** `~/.config/waybar/main-output`, which `Super+Shift+B` writes.
- **Extra clocks:** one IANA time zone per line (`America/New_York`; `timedatectl list-timezones` lists them) in `~/.config/waybar/timezones` adds that zone to Waybar's clock. With extra zones set, the clock shows every zone with its own date, ordered west to east, and the tooltip lists them under the calendar.
- **Temperature sensor:** Waybar reads Intel's `coretemp`. On an AMD machine, change `hwmon-name` in `.config/waybar/config.jsonc` to `k10temp`.

## Checking a change

The config reloads as soon as it's saved, and a broken one is kept out: niri shows an error and keeps running on the last good config. `niri validate` checks it from a terminal, and `./install.sh --verify` includes the same check.
