import time
import os
from kitty.fast_data_types import Screen, add_timer
from kitty.tab_bar import DrawData, ExtraData, TabBarData, draw_tab_with_powerline, as_rgb

INTERVAL = 5  # seconds between updates

# Palettes — keys map to the variant stored in ~/.config/theme/current.
# Order: BG, DATE, TIME, BAT, CPU, MEM, NET, IP, TEMP, SEP.
_CATPPUCCIN_PALETTES = {
    "frappe":    (0x232634, 0xe5c890, 0x99d1db, 0xa6d189, 0xef9f76,
                  0x85c1dc, 0xca9ee6, 0x81c8be, 0xe78284, 0x737994),
    "macchiato": (0x181926, 0xeed49f, 0x91d7e3, 0xa6da95, 0xf5a97f,
                  0x7dc4e4, 0xc6a0f6, 0x8bd5ca, 0xed8796, 0x6e738d),
    "mocha":     (0x11111b, 0xf9e2af, 0x89dceb, 0xa6e3a1, 0xfab387,
                  0x74c7ec, 0xcba6f7, 0x94e2d5, 0xf38ba8, 0x6c7086),
}

# Gruvbox's "bright" set (dark bg accents).
_GRUVBOX_PALETTES = {
    "dark":  (0x282828, 0xfabd2f, 0x83a598, 0xb8bb26, 0xfe8019,
              0x8ec07c, 0xd3869b, 0x689d6a, 0xfb4934, 0x928374),
}

_DRACULA_PALETTES = {
    "dark":  (0x282a36, 0xf1fa8c, 0x8be9fd, 0x50fa7b, 0xffb86c,
              0xbd93f9, 0xff79c6, 0x8be9fd, 0xff5555, 0x6272a4),
}

_FAMILIES = {
    "catppuccin": _CATPPUCCIN_PALETTES,
    "gruvbox":    _GRUVBOX_PALETTES,
    "dracula":    _DRACULA_PALETTES,
}


def _load_palette() -> tuple[int, ...]:
    family, variant = "catppuccin", "mocha"
    try:
        with open(os.path.expanduser("~/.config/theme/current")) as f:
            parts = f.readline().split()
            if len(parts) == 2 and parts[0] in _FAMILIES and parts[1] in _FAMILIES[parts[0]]:
                family, variant = parts
    except OSError:
        pass
    return _FAMILIES[family][variant]


_BG, _DATE, _TIME, _BAT, _CPU, _MEM, _NET, _IP, _TEMP, _SEP = _load_palette()

_timer_id = None
_cache: list[tuple[int, str]] = []  # computed once per tick, reused on every draw

# raw state for delta calculations
_prev_stat = None
_prev_net  = None


# ── CPU ───────────────────────────────────────────────────────────────────────

def _read_stat() -> tuple[int, int] | None:
    try:
        fields = list(map(int, open("/proc/stat").readline().split()[1:]))
        return sum(fields), fields[3] + fields[4]
    except OSError:
        return None


def _cpu_usage() -> str:
    global _prev_stat
    cur = _read_stat()
    if cur is None:
        return ""
    result = ""
    if _prev_stat is not None:
        d_total = cur[0] - _prev_stat[0]
        d_idle  = cur[1] - _prev_stat[1]
        if d_total > 0:
            result = f"{100.0 * (1.0 - d_idle / d_total):.0f}%"
    _prev_stat = cur
    return result


def _cpu_freq() -> str:
    base, freqs = "/sys/devices/system/cpu", []
    try:
        for entry in os.listdir(base):
            if not entry.startswith("cpu") or not entry[3:].isdigit():
                continue
            try:
                freqs.append(int(open(f"{base}/{entry}/cpufreq/scaling_cur_freq").read()))
            except OSError:
                pass
    except OSError:
        pass
    return f"{sum(freqs) / len(freqs) / 1_000_000:.2f}GHz" if freqs else ""


# ── Memory ────────────────────────────────────────────────────────────────────

def _memory() -> str:
    try:
        info = {}
        for line in open("/proc/meminfo"):
            k, v = line.split(":", 1)
            info[k.strip()] = int(v.split()[0])
        total, avail = info["MemTotal"], info["MemAvailable"]
        used = total - avail
        return f"{100.0 * used / total:.0f}% {used/1024/1024:.1f}/{total/1024/1024:.1f}GB"
    except OSError:
        return ""


# ── Network ───────────────────────────────────────────────────────────────────

def _active_ifaces() -> list[tuple[str, str]]:
    result, base = [], "/sys/class/net"
    try:
        for iface in os.listdir(base):
            if iface == "lo":
                continue
            try:
                if open(f"{base}/{iface}/operstate").read().strip() != "up":
                    continue
            except OSError:
                continue
            result.append((iface, "wifi" if iface.startswith("w") else "eth"))
    except OSError:
        pass
    return result


def _wifi_signal(iface: str) -> str:
    try:
        for line in open("/proc/net/wireless"):
            if line.strip().startswith(iface):
                dbm = float(line.split()[3].rstrip("."))
                return f"{dbm:.0f}dBm"
    except OSError:
        pass
    return ""


def _net_speed() -> list[tuple[str, str, str, str]]:
    global _prev_net
    now, base, cur = time.monotonic(), "/sys/class/net", {}
    for iface, kind in _active_ifaces():
        try:
            rx = int(open(f"{base}/{iface}/statistics/rx_bytes").read())
            tx = int(open(f"{base}/{iface}/statistics/tx_bytes").read())
            cur[iface] = (rx, tx, kind)
        except OSError:
            pass

    results = []
    if _prev_net is not None:
        elapsed = now - _prev_net["_ts"]
        if elapsed > 0:
            for iface, (rx, tx, kind) in cur.items():
                if iface not in _prev_net:
                    continue
                p_rx, p_tx, _ = _prev_net[iface]
                dl = (rx - p_rx) / elapsed / 1024 / 1024
                ul = (tx - p_tx) / elapsed / 1024 / 1024

                def fmt(mbs: float) -> str:
                    return f"{mbs:.1f}MB/s" if mbs >= 1 else f"{mbs * 1024:.0f}KB/s"

                icon   = "󰤨" if kind == "wifi" else "󰈀"
                signal = _wifi_signal(iface) if kind == "wifi" else ""
                results.append((iface, icon, f"↓{fmt(dl)} ↑{fmt(ul)}", signal))

    _prev_net = {"_ts": now, **{iface: v for iface, v in cur.items()}}
    return results


# ── Temperature ───────────────────────────────────────────────────────────────

def _temp(hwmon_name: str, temp_file: str = "temp1_input") -> int | None:
    base = "/sys/class/hwmon"
    try:
        for entry in os.listdir(base):
            try:
                if open(f"{base}/{entry}/name").read().strip() == hwmon_name:
                    return int(open(f"{base}/{entry}/{temp_file}").read().strip()) // 1000
            except OSError:
                continue
    except OSError:
        pass
    return None


def _temperatures() -> str:
    _CPU_SENSORS = ["coretemp", "k10temp", "zenpower", "k8temp", "cpu_thermal"]
    _GPU_SENSORS = ["amdgpu", "nouveau", "i915"]

    parts = []
    for name in _CPU_SENSORS:
        val = _temp(name)
        if val is not None:
            parts.append(f"CPU {val}°C")
            break
    for name in _GPU_SENSORS:
        val = _temp(name)
        if val is not None:
            parts.append(f"GPU {val}°C")
            break
    return "  ".join(parts)


# ── Battery ───────────────────────────────────────────────────────────────────

def _battery() -> tuple[str, str] | tuple[None, None]:
    for name in ("BAT0", "BAT1", "BAT"):
        try:
            cap    = open(f"/sys/class/power_supply/{name}/capacity").read().strip()
            status = open(f"/sys/class/power_supply/{name}/status").read().strip()
            return ("󰂄" if status == "Charging" else "󰁹"), f"{cap}%"
        except OSError:
            continue
    return None, None


# ── SSH / hostname detection ──────────────────────────────────────────────────

import re

# SSH flags that consume the next argument (not combined with the destination)
_SSH_FLAGS_WITH_ARGS = set("bcDEeFIiJLlmopQRSWw")
_IP_RE = re.compile(r"^\d{1,3}(?:\.\d{1,3}){3}$")


def _parse_ssh_dest(cmdline: list[str]) -> str | None:
    """Return the [user@]host destination from an ssh / kitten-ssh command line."""
    args = cmdline[1:]
    # kitten ssh <dest> → skip the leading 'ssh' subcommand word
    if args and args[0] == "ssh":
        args = args[1:]
    i = 0
    while i < len(args):
        a = args[i]
        if a.startswith("-"):
            # -X val  (two-token option)
            if len(a) == 2 and a[1] in _SSH_FLAGS_WITH_ARGS:
                i += 2
            else:
                i += 1
        else:
            return a  # first non-option is the destination
    return None


def _active_host_info() -> tuple[str, str | None]:
    """
    Returns (hostname, ip) for the current context:
    - SSH session active: (dest, None)  — dest is already [user@]host or host:ip
    - Local:             (hostname, ip) — separate segments, separate icons
    """
    try:
        from kitty.boss import get_boss
        boss = get_boss()
        for tm in boss.all_tab_managers:
            active_tab = tm.active_tab
            if active_tab is None:
                continue
            active_window = active_tab.active_window
            if active_window is None:
                continue
            for proc in active_window.child.foreground_processes:
                cmdline = proc.get("cmdline", [])
                if not cmdline:
                    continue
                prog = os.path.basename(cmdline[0])
                # matches: ssh, kitten (kitten ssh …), any *-ssh wrapper
                if prog == "ssh" or prog == "kitten" or prog.endswith("-ssh"):
                    dest = _parse_ssh_dest(cmdline)
                    if dest:
                        # Extract IP from cmdline dest when available
                        ip: str | None = None
                        if "@" in dest:
                            _, host = dest.split("@", 1)
                            if _IP_RE.match(host):
                                ip = host
                        elif _IP_RE.match(dest):
                            ip = dest

                        # Prefer window title for the display label — shell
                        # integration sets it to "user@hostname: dir" on the
                        # remote, giving us the real hostname rather than the IP.
                        title = getattr(active_window, "title", "") or ""
                        m = re.match(r"^([\w.-]+@[\w.-]+)", title)
                        if m:
                            return m.group(1), ip

                        # Fall back: show user (without the IP) from cmdline
                        if ip and "@" in dest:
                            return dest.split("@", 1)[0], ip
                        return dest, None
    except Exception:
        pass
    try:
        import socket
        user = os.getenv("USER") or os.getenv("LOGNAME") or ""
        hostname = socket.gethostname()
        label = f"{user}@{hostname}" if user else hostname
        ip: str | None = None
        try:
            # Connect to a public addr without sending data to find primary interface
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
                s.connect(("8.8.8.8", 80))
                ip = s.getsockname()[0]
        except Exception:
            pass
        return label, ip
    except Exception:
        return "", None


# ── Cache update (called only by timer) ──────────────────────────────────────

def _update_cache() -> None:
    global _cache
    segments = []

    # hostname is intentionally NOT cached here — it is resolved dynamically
    # in draw_tab so it reflects the active window's SSH state on every draw.

    cpu_text = "  ".join(p for p in [_cpu_usage(), _cpu_freq()] if p)
    if cpu_text:
        segments.append((_CPU, f"󰍛 {cpu_text}"))

    mem = _memory()
    if mem:
        segments.append((_MEM, f"󰍺 {mem}"))

    temps = _temperatures()
    if temps:
        segments.append((_TEMP, f"󰔏 {temps}"))

    for _iface, icon, speed, signal in _net_speed():
        text = f"{icon} {speed}" + (f" {signal}" if signal else "")
        segments.append((_NET, text))

    bat_icon, bat_val = _battery()
    if bat_icon:
        segments.append((_BAT, f"{bat_icon} {bat_val}"))

    segments.append((_DATE, time.strftime("󰃭 %d-%m-%Y")))
    segments.append((_TIME, time.strftime("󰥔 %H:%M")))
    _cache = segments


# Seed baselines and initial cache at import time
_prev_stat = _read_stat()
_net_speed()
time.sleep(0.2)  # short pause so first CPU delta is meaningful
_update_cache()


# ── Kitty draw ────────────────────────────────────────────────────────────────

def _on_timer(timer_id: int) -> None:
    _update_cache()
    from kitty.boss import get_boss
    for tm in get_boss().all_tab_managers:
        tm.mark_tab_bar_dirty()


def draw_tab(
    draw_data: DrawData,
    screen: Screen,
    tab: TabBarData,
    before: int,
    max_tab_length: int,
    index: int,
    is_last: bool,
    extra_data: ExtraData,
) -> int:
    global _timer_id
    if _timer_id is None:
        _timer_id = add_timer(_on_timer, INTERVAL, True)

    end = draw_tab_with_powerline(
        draw_data, screen, tab, before, max_tab_length, index, is_last, extra_data
    )

    if is_last:
        # Priority order: drop from the front first (hostname, then cpu freq, etc.)
        # Each entry: (drop_group, color, text)
        # drop_group 0 = drop last, drop_group 4 = drop first
        DROP_HOSTNAME  = 4
        DROP_FREQ      = 3
        DROP_TEMP      = 2
        DROP_DATE      = 1
        DROP_NEVER     = 0

        tagged = []

        # Dynamic hostname/IP: SSH dest (single segment) or local hostname + IP
        host, ip = _active_host_info()
        if host:
            tagged.append((DROP_HOSTNAME, _NET, f"󰟀 {host}"))
        if ip:
            tagged.append((DROP_HOSTNAME, _IP, f"󰩟 {ip}"))

        for color, text in _cache:
            if text.startswith("󰃭"):
                tagged.append((DROP_DATE, color, text))
            elif text.startswith("󰍛"):
                # split cpu% and freq into separate tagged items
                inner = text[len("󰍛 "):]
                parts = inner.split("  ")
                tagged.append((DROP_NEVER, color, f"󰍛 {parts[0]}"))
                if len(parts) > 1:
                    tagged.append((DROP_FREQ, color, parts[1]))
            elif text.startswith("󰔏"):
                tagged.append((DROP_TEMP, color, text))
            else:
                tagged.append((DROP_NEVER, color, text))

        sep = "  "
        available = screen.columns - screen.cursor.x - 1

        # Drop groups from highest priority downward until it fits
        for threshold in range(max(g for g, _, _ in tagged), -1, -1):
            visible = [(c, t) for g, c, t in tagged if g <= threshold]
            full = sep.join(t for _, t in visible) + " "
            if len(full) <= available:
                break
        else:
            visible = []

        if visible:
            full = sep.join(t for _, t in visible) + " "
            x = screen.columns - len(full)
            screen.cursor.x = x
            screen.cursor.bg = as_rgb(_BG)
            screen.cursor.bold = True
            for i, (color, text) in enumerate(visible):
                screen.cursor.fg = as_rgb(color)
                screen.draw(text)
                if i < len(visible) - 1:
                    screen.cursor.fg = as_rgb(_SEP)
                    screen.draw(sep)
            screen.draw(" ")

    return end
