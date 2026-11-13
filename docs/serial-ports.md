# Serial ports

`--setup` makes USB-serial adapters usable as soon as they are plugged in:

- **Access.** Ubuntu gives every `ttyUSB*` and `ttyACM*` to the `dialout` group with read/write access, so `--setup` adds you to it. Log out and back in once for it to apply.
- **Latency.** FTDI chips hold received bytes for up to 16 ms before sending a short packet, which stalls request/response protocols. [`etc/udev/rules.d/98-ftdi-latency.rules`](../etc/udev/rules.d/98-ftdi-latency.rules) sets that timer to 1 ms on every FTDI port. It matches the kernel driver (`ftdi_sio`), not a vendor/product ID or serial number, so it covers FT232R, FT2232, FT4232, FT232H and every other chip the driver supports. Other chips (CH340/CH343, CP210x, CDC-ACM) have no latency timer on Linux and are left alone.

The rule is copied into `/etc/udev/rules.d`, not symlinked, and takes effect from the next plug-in. Check a port with `cat /sys/bus/usb-serial/devices/ttyUSB0/latency_timer`. `--verify` fails when you are not in `dialout` or the installed rule differs from the repo's.

Per-device names and exceptions are machine-specific, so they stay out of the repo. Put them in a `99-*.rules` file in `/etc/udev/rules.d`: it runs after this one, so a `RUN` there can set a different latency for one adapter.

**`ports`** shows what is plugged in, from udev and `/sys` (no root needed):

```
$ ports
DEVICE        PRODUCT            SERIAL    DRIVER    LATENCY  PORT  STABLE PATH
/dev/ttyACM0  USB Serial Device  E6614C31  cdc_acm   —        3-2   /dev/serial/by-id/usb-Example_USB_Serial_Device_E6614C31-if00
/dev/ttyUSB0  FT232R USB UART    A10KLMNO  ftdi_sio  1 ms     3-1   /dev/serial/by-id/usb-FTDI_FT232R_USB_UART_A10KLMNO-if00-port0
/dev/ttyUSB1  USB Serial         —         ch341     —        3-4   /dev/serial/by-id/usb-1a86_USB_Serial-if00-port0

$ ports -w
DEVICE        PRODUCT            SERIAL    DRIVER    LATENCY  PORT  STABLE PATH
/dev/ttyACM0  USB Serial Device  E6614C31  cdc_acm   —        3-2   /dev/serial/by-id/usb-Example_USB_Serial_Device_E6614C31-if00
/dev/ttyUSB0  FT232R USB UART    A10KLMNO  ftdi_sio  1 ms     3-1   /dev/serial/by-id/usb-FTDI_FT232R_USB_UART_A10KLMNO-if00-port0
/dev/ttyUSB1  USB Serial         —         ch341     —        3-4   /dev/serial/by-id/usb-1a86_USB_Serial-if00-port0

Watching for plug and unplug — Ctrl-C to stop
20:24:36  − /dev/ttyUSB1  USB Serial       —
20:24:41  + /dev/ttyUSB1  USB Serial       —         ch341     —     USB port 3-3
20:24:47  − /dev/ttyUSB0  FT232R USB UART  A10KLMNO
20:24:52  + /dev/ttyUSB0  FT232R USB UART  A10KLMNO  ftdi_sio  1 ms  USB port 3-1
```

| Command | Does |
|---|---|
| `ports` | Lists every USB serial port: product string, serial number, driver, latency timer, USB port and stable path. FT2232/FT4232 channels are named `(A)`, `(B)`, … A name a local udev rule gives a port (`SYMLINK+="debug-uart"`) shows in an ALIAS column, which appears only when some port has one |
| `ports -w` | Lists them, then prints a timestamped `+` or `−` line each time an adapter is plugged in or out, until `Ctrl-C` |
| `ports --notify` | Sends a desktop notification each time an adapter is plugged in or out, naming its ttys, aliases and product; the channels of a multi-channel adapter arrive as one notification. Meant to run in the background: the [niri](niri.md) session starts it at login, and a second copy exits at once |
| `ports share DEVICE [PORT]` | Shares DEVICE on the network on TCP PORT as well as whatever is shared already, now and at boot, or moves it to PORT (below) |
| `ports unshare DEVICE\|PORT` | Stops sharing that one; the others stay shared and connected |
| `ports unshare [--all]` | Stops sharing all of them, now and at boot. Bare, only when one is shared; with several it lists them and asks which |

Colours follow the theme picked with `--theme`, in the same roles as the prompt; the latency shows green at 1 ms and orange at anything else. Piped output is plain text.

The stable path (`/dev/serial/by-id/…`) is created by udev for every adapter. It names the adapter by its product and serial number, so it stays the same whichever USB socket it is in and whichever `ttyUSB` number it gets — usually no need for a per-device alias. Pass it to any tool that takes a port.

**`ports share`** shares adapters on the network, each on its own TCP port, so another machine opens one as `rfc2217://<host>:<port>` with any RFC 2217 client (pyserial's `serial_for_url`, for one), as if it were plugged in there. While any is shared, `ports` marks them in a SHARED column, which appears only then, and lists the address to give for each, on Ethernet when there is a cable, with who is connected:

```
$ ports share ttyUSB0
$ ports share ttyACM0
DEVICE        PRODUCT            SERIAL    DRIVER    LATENCY  PORT  SHARED  STABLE PATH
/dev/ttyACM0  USB Serial Device  E6614C31  cdc_acm   —        3-2   :4001   /dev/serial/by-id/usb-Example_USB_Serial_Device_E6614C31-if00
/dev/ttyUSB0  FT232R USB UART    A10KLMNO  ftdi_sio  1 ms     3-1   :4000   /dev/serial/by-id/usb-FTDI_FT232R_USB_UART_A10KLMNO-if00-port0
/dev/ttyUSB1  USB Serial         —         ch341     —        3-4   —       /dev/serial/by-id/usb-1a86_USB_Serial-if00-port0

● Shared on the network over Ethernet  (also after a reboot; ser2net 4.6.8)
  /dev/ttyUSB0  rfc2217://192.168.1.20:4000  connected: 192.168.1.35
  /dev/ttyACM0  rfc2217://192.168.1.20:4001  nobody connected
  Also on Wi-Fi as 192.168.1.21, same ports
  One client per port: whoever connects last takes it.
```

`ttyUSB0` means `/dev/ttyUSB0`; an alias or a stable path works too. PORT defaults to the one DEVICE is already shared on, else the first free from 4000. `ports unshare` takes a device or a port: `ports unshare ttyACM0` and `ports unshare 4001` are the same.

- **ser2net is built from source, not taken from apt.** `--setup` (or `./install.sh --ser2net` alone) builds the newest tags of [ser2net](https://github.com/cminyard/ser2net) and [gensio](https://github.com/cminyard/gensio), the library that speaks RFC 2217 for it, into `/usr/local`, and installs [`etc/systemd/system/ser2net.service`](../etc/systemd/system/ser2net.service) disabled; `share` enables it. Ubuntu's ser2net 4.6.0 never answers an RFC 2217 PURGE-DATA, which clients such as pyserial wait for before they open the port, so it is removed (its `/etc/ser2net.yaml` stays). Re-running picks up newer tags; build logs go to `~/.cache/dotfiles/`.
- **The config is generated, never edited.** `share` and `unshare` rewrite `/etc/ser2net.yaml`, one connection per shared adapter, with what matters fixed: `telnet(rfc2217)`, so the client can set the baud rate and send BREAKs, and `tcp(nodelay)`, without which ser2net holds back the second half of any reply longer than one FTDI USB packet (62 bytes) and reads time out. The first `share` keeps what was there before as `/etc/ser2net.yaml.orig`.
- **Adding or removing one share leaves the others connected.** A change reloads ser2net (SIGHUP) instead of restarting it. A share being removed is disabled first, which kicks its client off at once; deleted outright, ser2net would keep it until the client disconnected.
- **Ethernet, not Wi-Fi.** Over Wi-Fi a remote bench sees timeouts; over a cable it needs no extra latency flags. The address list puts Ethernet first.
- **No password.** Anyone on the network can open the port while it is shared, which is why the last `unshare` disables it at boot as well.
- **This machine can still use the adapter** while nobody is connected; ser2net opens it only for a client. Or connect through the share like everyone else: `rfc2217://localhost:4000`.
- **A stable path survives replugging.** `ports share /dev/serial/by-id/…` keeps sharing the same adapter whichever `ttyUSB` number it gets next time.
