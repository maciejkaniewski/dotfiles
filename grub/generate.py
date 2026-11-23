#!/usr/bin/env python3
"""Generates the GRUB boot-menu themes in grub/themes, one per dotfiles theme.

Each is the same layout in that theme's colours: the menu straight on the niri
wallpaper's glows, with no panel, the selected entry in the accent colour
beside an accent rail and the rest dimmed, a countdown bar, and the keys to
press underneath, all in Terminus. Colours come from the repo's own theme files
(kitty for base/text/surface/grey, gtk-3.0 for the accent, the niri wallpaper
SVG for the glows), so the boot menu matches the desktop it starts.

A maintainer tool: run it after changing a palette or the layout, and commit
what it writes. It needs Python with Pillow, Terminus (fonts-terminus-otb)
for the key hints and FiraCode Nerd Font (install.sh puts it in
~/.local/share/fonts) for two icons. install.sh itself never runs it; it only
copies the result into /boot/grub/themes/dotfiles.

The menu is in Terminus, a bitmap font: GRUB draws fonts as 1-bit bitmaps,
which leaves an outline font like FiraCode ragged on a real screen, while
Terminus is drawn pixel by pixel and stays sharp. install.sh converts it with
grub-mkfont; GRUB knows the results as "Terminus Regular 20" and "... 16".

    python3 grub/generate.py            # all themes
    python3 grub/generate.py --preview  # also quick mock-ups at 1920x1200,
                                        # 2560x1440 and 3440x1440 in /tmp
    grub/preview.sh STUB [WxH ...]      # the real thing: GRUB in QEMU

The mock-ups only approximate GRUB; check a layout change with preview.sh.

Positions in theme.txt are percentages, so the panel stays centred at any
resolution; GRUB can't scale fonts or images, so their sizes are fixed pixels
chosen to fit from 1024x768 up.
"""
import os
import re
import shutil
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

GRUB = os.path.dirname(os.path.abspath(__file__))
DOT = os.path.dirname(GRUB)
FONTS = os.path.expanduser("~/.local/share/fonts")
TERMINUS = "/usr/share/fonts/opentype/terminus/terminus-bold.otb"
STUBS = ["frappe", "macchiato", "mocha", "gruvbox-dark", "dracula"]

# Layout, in GRUB's pixels. The menu is the boot_menu component, with no box
# around it; the selected entry's box is only its left edge, the rail.
MENU_W = 572
ITEM_H, ITEM_SP, ITEM_PAD, ICON, ICON_SP = 44, 6, 20, 28, 16
# The rail: its width, the clear gap after it, and its gap above and below.
# GRUB draws the selected box at the item's padding and starts every entry's
# icon after the box's left edge, so the gap is part of the image.
RAIL_W, RAIL_GAP, RAIL_INSET = 4, 12, 8
# GRUB 2.06 makes a progress bar at least 28 px tall whatever its height says,
# so its images are 28 px with the 4 px stripe in the middle, the rest clear.
# The splash (plymouth/generate.py) takes the same width.
BAR_W, BAR_H, BAR_STRIPE = MENU_W, 28, 4
# GRUB fits (height + spacing - 2*padding) / (item height + spacing) entries,
# so 4 need 234. More than fit scroll, with the bar.
MENU_H = 234
MENU_TOP = -150           # menu's top edge, relative to 50%
BAR_TOP = 86              # countdown bar, under the menu (GRUB draws the menu over anything inside it)
LABEL_TOP = 118           # "Booting in %d s", relative to 50%
HINTS_FROM_BOTTOM = 100   # key hints image, relative to 100%
BG_W, BG_H = 1920, 1200   # background, stretched to the screen
HINTS = [("↑↓", "select"), ("enter", "boot"), ("e", "edit"), ("c", "console")]
# Icons for entries that catppuccin/grub's set has none for, drawn from
# FiraCode Nerd Font: GRUB picks an entry's icon by its --class, and install.sh
# gives Ubuntu's "Advanced options" submenu and the UEFI entry these classes.
GLYPH_ICONS = {"submenu": "\U000F024B",   # nf-md-folder
               "efi": "\U000F0493"}       # nf-md-cog


def rgba(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def palette(stub):
    kitty = open(f"{DOT}/.config/kitty/{stub}.conf").read()
    k = lambda key: re.search(rf"^{key}\s+(#[0-9a-fA-F]{{6}})", kitty, re.M).group(1)
    gtk = open(f"{DOT}/.config/gtk-3.0/{stub}.css").read()
    acc = re.search(r"accent_bg_color\s+(#[0-9a-fA-F]{6})", gtk).group(1)
    return dict(base=k("background"), text=k("foreground"),
                surf=k("active_tab_background"), dim=k("color8"), acc=acc)


def background(stub):
    """The niri wallpaper (.config/niri/wallpapers/<stub>.svg) drawn with
    Pillow: its base gradient and its blurred glows, at BG_W x BG_H."""
    svg = open(f"{DOT}/.config/niri/wallpapers/{stub}.svg").read()
    stops = re.findall(r'stop-color="(#[0-9a-fA-F]{6})"', svg)
    a, b = rgba(stops[0]), rgba(stops[-1])
    img = Image.new("RGBA", (BG_W, BG_H))
    d = ImageDraw.Draw(img)
    for y in range(BG_H):  # the SVG's gradient runs corner to corner; top to bottom reads the same
        t = y / (BG_H - 1)
        d.line([(0, y), (BG_W, y)], fill=tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,))
    vb_w, vb_h = map(float, re.search(r'viewBox="0 0 ([\d.]+) ([\d.]+)"', svg).groups())
    blur = float(re.search(r'stdDeviation="([\d.]+)"', svg).group(1))
    sx, sy = BG_W / vb_w, BG_H / vb_h
    glows = Image.new("RGBA", (BG_W, BG_H), (0, 0, 0, 0))
    for cx, cy, rx, ry, fill, op in re.findall(
            r'<ellipse cx="([\d.]+)"\s+cy="([\d.]+)"\s+rx="([\d.]+)"\s+ry="([\d.]+)"\s+'
            r'fill="(#[0-9a-fA-F]{6})"\s+opacity="([\d.]+)"', svg):
        cx, cy, rx, ry = float(cx) * sx, float(cy) * sy, float(rx) * sx, float(ry) * sy
        e = Image.new("RGBA", (BG_W, BG_H), (0, 0, 0, 0))
        ImageDraw.Draw(e).ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=rgba(fill, round(255 * float(op))))
        glows = Image.alpha_composite(glows, e)
    return Image.alpha_composite(img, glows.filter(ImageFilter.GaussianBlur(blur * sx)))


def rounded(w, h, r, fill, outline=None, width=0, scale=4):
    """A rounded rectangle, drawn 4x and scaled down for smooth corners."""
    big = Image.new("RGBA", (w * scale, h * scale), (0, 0, 0, 0))
    ImageDraw.Draw(big).rounded_rectangle([0, 0, w * scale - 1, h * scale - 1], radius=r * scale,
                                          fill=fill, outline=outline, width=width * scale)
    return big.resize((w, h), Image.LANCZOS)


def hints(p):
    """The key hints, in Terminus 16 like the countdown above them, drawn at
    its own size (a bitmap font has no other): each key in the text colour,
    what it does dimmed."""
    font = ImageFont.truetype(TERMINUS, 16)
    probe = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    cells = [(k, v, probe.textlength(k, font=font), probe.textlength(v, font=font)) for k, v in HINTS]
    gap, h = 40, 24
    w = int(sum(kw + 8 + vw for _, _, kw, vw in cells) + gap * (len(cells) - 1)) + 4
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    x = 2
    for k, v, kw, vw in cells:
        d.text((round(x), h // 2), k, font=font, fill=rgba(p["text"]), anchor="lm")
        d.text((round(x + kw + 8), h // 2), v, font=font, fill=rgba(p["dim"]), anchor="lm")
        x += kw + 8 + vw + gap
    return img


def glyph_icon(char, col, size=32):
    s = 4
    font = ImageFont.truetype(f"{FONTS}/FiraCodeNerdFont-Regular.ttf", 26 * s)
    big = Image.new("RGBA", (size * s, size * s), (0, 0, 0, 0))
    ImageDraw.Draw(big).text((size * s / 2, size * s / 2), char, font=font, fill=rgba(col), anchor="mm")
    return big.resize((size, size), Image.LANCZOS)


def recolour(src, col):
    im = Image.open(src).convert("RGBA")
    solid = Image.new("RGBA", im.size, rgba(col))
    solid.putalpha(im.getchannel("A"))
    return solid


def save(im, path):
    # GRUB's PNG reader takes 8-bit RGB(A), non-interlaced; Pillow writes that from RGBA.
    im.convert("RGBA").save(path, optimize=True)


THEME_TXT = """\
# GRUB boot menu, {name}. Written by grub/generate.py — change that and re-run
# it rather than editing this file. Icons: catppuccin/grub (MIT, grub/icons/LICENSE).

title-text: ""
desktop-image: "background.png"
desktop-image-scale-method: "stretch"
desktop-color: "{base}"
# GRUB's text console — shown while it loads Linux after a pick, and for the
# "c" console — covers the whole screen with no frame, over the background.
# Framed, it showed as a large empty panel during every boot (quiet boot
# prints nothing into it).
terminal-font: "Unifont Regular 16"
terminal-left: "0"
terminal-top: "0"
terminal-width: "100%"
terminal-height: "100%"
terminal-border: "0"

# Wider than the bar by the item padding on each side, so the rail lines up
# with the bar's left end.
+ boot_menu {{
  left = 50%-{box_half}
  top = 50%{menu_top}
  width = {box_w}
  height = {menu_h}
  item_font = "Terminus Regular 20"
  selected_item_font = "Terminus Regular 20"
  item_color = "{dim}"
  selected_item_color = "{acc}"
  selected_item_pixmap_style = "select_*.png"
  icon_width = {icon}
  icon_height = {icon}
  item_icon_space = {icon_sp}
  item_height = {item_h}
  item_padding = {item_pad}
  item_spacing = {item_sp}
  scrollbar = true
  scrollbar_width = 4
  scrollbar_thumb = "scroll_thumb_*.png"
}}

+ progress_bar {{
  id = "__timeout__"
  left = 50%-{bar_half}
  top = 50%+{bar_top}
  width = {bar_w}
  height = {bar_h}
  bar_style = "progress_bar_*.png"
  highlight_style = "progress_highlight_*.png"
  show_text = false
}}

+ label {{
  id = "__timeout__"
  left = 50%-{half_w}
  top = 50%+{label_top}
  width = {menu_w}
  align = "center"
  text = "Booting in %d s"
  font = "Terminus Regular 16"
  color = "{dim}"
}}

+ image {{
  left = 50%-{hints_half}
  top = 100%-{hints_bottom}
  file = "hints.png"
}}
"""


def generate(stub):
    p = palette(stub)
    out = f"{GRUB}/themes/{stub}"
    shutil.rmtree(out, ignore_errors=True)
    os.makedirs(f"{out}/icons")
    save(background(stub).convert("RGB"), f"{out}/background.png")
    # The selected entry's box is its left edge alone: no centre or other
    # edges, so GRUB blends nothing across the row. On real firmware it blends
    # translucent images pixel by pixel on every key press, which lagged and
    # flashed black on a ThinkPad with a translucent panel (QEMU hides it).
    rail = Image.new("RGBA", (RAIL_W + RAIL_GAP, ITEM_H), (0, 0, 0, 0))
    rail.alpha_composite(rounded(RAIL_W, ITEM_H - 2 * RAIL_INSET, 2, rgba(p["acc"])), (0, RAIL_INSET))
    save(rail, f"{out}/select_w.png")
    # The countdown bar as images: GRUB 2.06 draws a progress_bar's plain
    # fg_color/bg_color at about a fifth of their opacity, seen in QEMU.
    for name, col in (("progress_bar", p["surf"]), ("progress_highlight", p["acc"])):
        bar = Image.new("RGBA", (5, BAR_H), (0, 0, 0, 0))
        bar.alpha_composite(rounded(5, BAR_STRIPE, 2, rgba(col)), (0, (BAR_H - BAR_STRIPE) // 2))
        save(bar.crop((0, 0, 2, BAR_H)), f"{out}/{name}_w.png")
        save(bar.crop((2, 0, 3, BAR_H)), f"{out}/{name}_c.png")
        save(bar.crop((3, 0, 5, BAR_H)), f"{out}/{name}_e.png")
    thumb = rounded(4, 2 * 2 + 1, 2, rgba(p["surf"]))
    save(thumb.crop((0, 0, 4, 2)), f"{out}/scroll_thumb_n.png")
    save(thumb.crop((0, 2, 4, 3)), f"{out}/scroll_thumb_c.png")
    save(thumb.crop((0, 3, 4, 5)), f"{out}/scroll_thumb_s.png")
    h = hints(p)
    save(h, f"{out}/hints.png")
    # Dimmed like the entries: GRUB shows the same icon whether or not its
    # entry is selected.
    for f in sorted(os.listdir(f"{GRUB}/icons")):
        if f.endswith(".png"):
            save(recolour(f"{GRUB}/icons/{f}", p["dim"]), f"{out}/icons/{f}")
    for cls, char in GLYPH_ICONS.items():
        save(glyph_icon(char, p["dim"]), f"{out}/icons/{cls}.png")
    name = {"gruvbox-dark": "Gruvbox Dark", "dracula": "Dracula"}.get(stub, f"Catppuccin {stub.capitalize()}")
    open(f"{out}/theme.txt", "w").write(THEME_TXT.format(
        name=name, half_w=MENU_W // 2, menu_top=f"{MENU_TOP:+d}", menu_w=MENU_W, menu_h=MENU_H,
        box_half=MENU_W // 2 + ITEM_PAD, box_w=MENU_W + 2 * ITEM_PAD,
        icon=ICON, icon_sp=ICON_SP, item_h=ITEM_H, item_pad=ITEM_PAD, item_sp=ITEM_SP,
        bar_half=BAR_W // 2, bar_top=BAR_TOP, bar_w=BAR_W, bar_h=BAR_H,
        label_top=LABEL_TOP, hints_half=h.width // 2, hints_bottom=HINTS_FROM_BOTTOM, **p))
    return p


# ── Preview: GRUB's layout of the generated files, approximated with Pillow ──
ENTRIES = [("Ubuntu", "ubuntu"), ("Advanced options for Ubuntu", "submenu"),
           ("Windows Boot Manager (on /dev/nvme0n1p1)", "windows"), ("UEFI Firmware Settings", "efi")]


def preview(stub, p, W, H, path):
    t = f"{GRUB}/themes/{stub}"
    img = Image.open(f"{t}/background.png").convert("RGBA").resize((W, H), Image.BILINEAR)
    mx, my = W // 2 - MENU_W // 2, H // 2 + MENU_TOP
    d = ImageDraw.Draw(img)
    font = ImageFont.truetype(TERMINUS, 20)
    small = ImageFont.truetype(TERMINUS, 16)
    rail = Image.open(f"{t}/select_w.png")
    for i, (label, cls) in enumerate(ENTRIES):
        y = my + ITEM_PAD + i * (ITEM_H + ITEM_SP)
        if i == 0:
            img.alpha_composite(rail, (mx, y))
        ix = mx + rail.width
        img.alpha_composite(Image.open(f"{t}/icons/{cls}.png").convert("RGBA").resize((ICON, ICON), Image.LANCZOS),
                            (ix, y + (ITEM_H - ICON) // 2))
        d.text((ix + ICON + ICON_SP, y + ITEM_H // 2), label, font=font,
               fill=rgba(p["acc"] if i == 0 else p["dim"]), anchor="lm")
    bx, by = W // 2 - BAR_W // 2, H // 2 + BAR_TOP
    sy = by + (BAR_H - BAR_STRIPE) // 2
    d.rectangle([bx, sy, bx + BAR_W, sy + BAR_STRIPE - 1], fill=rgba(p["surf"]))
    d.rectangle([bx, sy, bx + int(BAR_W * 0.6), sy + BAR_STRIPE - 1], fill=rgba(p["acc"]))
    d.text((W // 2, H // 2 + LABEL_TOP + 10), "Booting in 3 s", font=small, fill=rgba(p["dim"]), anchor="mm")
    hi = Image.open(f"{t}/hints.png")
    img.alpha_composite(hi, (W // 2 - hi.width // 2, H - HINTS_FROM_BOTTOM))
    img.convert("RGB").save(path)


if __name__ == "__main__":
    want_preview = "--preview" in sys.argv
    outdir = os.environ.get("GRUB_PREVIEW_DIR", "/tmp/grub-theme-preview")
    if want_preview:
        os.makedirs(outdir, exist_ok=True)
    for stub in STUBS:
        p = generate(stub)
        print(f"grub/themes/{stub}")
        if want_preview:
            for W, H in ((1920, 1200), (2560, 1440), (3440, 1440)):
                preview(stub, p, W, H, f"{outdir}/{stub}-{W}x{H}.png")
    if want_preview:
        print(f"previews in {outdir}")
