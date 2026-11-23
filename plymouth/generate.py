#!/usr/bin/env python3
"""Generates the boot splashes in plymouth/themes, one per dotfiles theme.

The splash Plymouth shows while Ubuntu starts, and again while it shuts down
or restarts. It carries on from the GRUB menu (grub/generate.py): the same
background (copied from grub/themes by install.sh, so it isn't stored twice)
and, without the menu panel, the same thin bar in the accent colour, with
"Starting Ubuntu", "Shutting down" or "Restarting" under it in Terminus.

A short piece of the bar slides to and fro, like a spinner: how far a boot
has got can't be told reliably, so the bar doesn't pretend to. Should anything ask for a password (a disk encrypted with LUKS) or
show a message (fsck), the question takes the label's place, with a dot per
character typed.

The text is drawn here as images: Plymouth's own text goes through fontconfig
in the initramfs, where Ubuntu copies only its Ubuntu fonts, so Terminus would
silently turn into something else. Only a password prompt's or a message's
text, which can't be known in advance, uses that font.

A maintainer tool, like grub/generate.py, which it borrows the palette and
background from: run it after changing a palette or the layout and commit
what it writes. install.sh never runs it; it copies a theme's folder (plus
GRUB's background) into /usr/share/plymouth/themes/dotfiles.

    python3 plymouth/generate.py            # all themes
    python3 plymouth/generate.py --preview  # also a mock-up per theme in /tmp
"""
import os
import shutil
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True   # no __pycache__ left in grub/
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "grub"))
from generate import STUBS, TERMINUS, BAR_W, BAR_STRIPE, palette, rgba, rounded, background  # noqa: E402

LABELS = {"boot": "Starting Ubuntu", "shutdown": "Shutting down", "reboot": "Restarting"}
LABEL_GAP = 36      # from the bar to the middle of the label, as in the mock-up the user picked
SEGMENT_W = 140     # the sliding piece
MAX_BULLETS = 32    # dots for a password's characters

PLYMOUTH = """\
[Plymouth Theme]
Name=Dotfiles ({name})
Description=The dotfiles' boot splash: the GRUB menu's background and bar, in {name}.
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/dotfiles
ScriptFile=/usr/share/plymouth/themes/dotfiles/dotfiles.script
"""

# Plymouth's script language. With several screens Plymouth centres them on
# one another and draws the same scene on each: Window.GetWidth() with no
# number is the smallest screen's, so the bar and label sit in the middle of
# every one, and the background is stretched over the largest.
SCRIPT = """\
# The dotfiles' boot splash ({name}), written by plymouth/generate.py.

Window.SetBackgroundTopColor({base_f});
Window.SetBackgroundBottomColor({base_f});

# Plymouth puts every screen on one canvas the size of the largest, each
# centred in it, so the canvas's centre is every screen's centre. Window.GetX()
# without an index is the smallest screen's offset in it: added in, it moved
# everything right and down whenever screens of two sizes were lit.
W = Window.GetWidth();
H = Window.GetHeight();

background = Sprite(Image("background.png").Scale(W, H));
background.SetPosition(0, 0, -100);

bar_w = Math.Min({bar_w}, W - 64);
bar_x = Math.Int((W - bar_w) / 2);
bar_y = Math.Int(H / 2);

track = Sprite(Image("bar-track.png").Scale(bar_w, {stripe}));
track.SetPosition(bar_x, bar_y, 1);

mode = Plymouth.GetMode();
if (mode == "shutdown")
  label_image = Image("label-shutdown.png");
else if (mode == "reboot")
  label_image = Image("label-reboot.png");
else
  label_image = Image("label-boot.png");
label = Sprite(label_image);
label.SetPosition(Math.Int((W - label_image.GetWidth()) / 2),
                  bar_y + {label_gap} - Math.Int(label_image.GetHeight() / 2), 3);

# A short piece of the bar slides to and fro until the splash closes: how
# far a boot has got can't be told (Plymouth's estimate runs to the end of the
# whole boot, past the login screen, and moves from boot to boot), so the bar
# only says the machine is busy, like a spinner.
segment = Sprite(Image("bar-fill.png").Scale({segment_w}, {stripe}));
segment.SetPosition(bar_x, bar_y, 2);
frame = 0;

fun refresh() {{
  global.frame = global.frame + 1;
  room = global.bar_w - {segment_w};
  t = (1 - Math.Cos(global.frame / 40)) / 2;
  global.segment.SetPosition(global.bar_x + Math.Int(room * t), global.bar_y, 2);
}}
Plymouth.SetRefreshFunction(refresh);

# A password (an encrypted disk) or a question: its prompt in the label's
# place, a dot per character underneath (up to {max_bullets}, made up front).
question = Sprite();
bullet_image = Image("bullet.png");
for (i = 0; i < {max_bullets}; i++) {{
  bullets[i] = Sprite(bullet_image);
  bullets[i].SetOpacity(0);
}}

fun show_bullets(n) {{
  n = Math.Min(n, {max_bullets});
  step = 16;
  x0 = Math.Int((global.W - (n - 1) * step - global.bullet_image.GetWidth()) / 2);
  for (i = 0; i < {max_bullets}; i++) {{
    global.bullets[i].SetPosition(x0 + i * step, global.bar_y + {label_gap} + 24, 3);
    if (i < n) global.bullets[i].SetOpacity(1);
    else global.bullets[i].SetOpacity(0);
  }}
}}

fun show_question(text, n) {{
  image = Image.Text(text, {text_f}, 1, "Ubuntu Mono 13");
  global.question.SetImage(image);
  global.question.SetPosition(Math.Int((global.W - image.GetWidth()) / 2),
                              global.bar_y + {label_gap} - Math.Int(image.GetHeight() / 2), 3);
  global.question.SetOpacity(1);
  global.label.SetOpacity(0);
  show_bullets(n);
}}

fun display_password(text, n) {{
  if (text == "") text = "Password";
  show_question(text, n);
}}
Plymouth.SetDisplayPasswordFunction(display_password);

fun display_question(text, entry) {{
  show_question(text + " " + entry, 0);
}}
Plymouth.SetDisplayQuestionFunction(display_question);

fun display_normal() {{
  global.question.SetOpacity(0);
  global.label.SetOpacity(1);
  show_bullets(0);
}}
Plymouth.SetDisplayNormalFunction(display_normal);

# Messages (fsck and the like), small, well under the label.
message = Sprite();
fun display_message(text) {{
  image = Image.Text(text, {dim_f}, 1, "Ubuntu Mono 11");
  global.message.SetImage(image);
  global.message.SetPosition(Math.Int((global.W - image.GetWidth()) / 2),
                             global.bar_y + {label_gap} + 56, 3);
  global.message.SetOpacity(1);
}}
fun hide_message(text) {{
  global.message.SetOpacity(0);
}}
Plymouth.SetDisplayMessageFunction(display_message);
Plymouth.SetHideMessageFunction(hide_message);
"""


def floats(h):
    r, g, b, _ = rgba(h)
    return f"{r / 255:.3f}, {g / 255:.3f}, {b / 255:.3f}"


def label(text, col):
    """Terminus 16 at its own size: a bitmap font has no other, so it's as
    sharp as the GRUB menu's."""
    font = ImageFont.truetype(TERMINUS, 16)
    l, t, r, b = ImageDraw.Draw(Image.new("RGBA", (1, 1))).textbbox((0, 0), text, font=font)
    im = Image.new("RGBA", (r - l + 4, b - t + 4), (0, 0, 0, 0))
    ImageDraw.Draw(im).text((2 - l, 2 - t), text, font=font, fill=rgba(col))
    return im


def generate(stub):
    p = palette(stub)
    out = f"{HERE}/themes/{stub}"
    shutil.rmtree(out, ignore_errors=True)
    os.makedirs(out)
    # The bar's two colours as 1-pixel-wide strips, scaled to length by the
    # script; the ends of a 4-pixel bar are too small to round.
    Image.new("RGBA", (1, BAR_STRIPE), rgba(p["surf"])).save(f"{out}/bar-track.png")
    Image.new("RGBA", (1, BAR_STRIPE), rgba(p["acc"])).save(f"{out}/bar-fill.png")
    rounded(8, 8, 4, rgba(p["text"])).save(f"{out}/bullet.png")
    for mode, text in LABELS.items():
        label(text, p["dim"]).save(f"{out}/label-{mode}.png", optimize=True)
    name = {"gruvbox-dark": "Gruvbox Dark", "dracula": "Dracula"}.get(stub, f"Catppuccin {stub.capitalize()}")
    open(f"{out}/dotfiles.plymouth", "w").write(PLYMOUTH.format(name=name))
    open(f"{out}/dotfiles.script", "w").write(SCRIPT.format(
        name=name, base_f=floats(p["base"]), text_f=floats(p["text"]), dim_f=floats(p["dim"]),
        bar_w=BAR_W, stripe=BAR_STRIPE, label_gap=LABEL_GAP, segment_w=SEGMENT_W, max_bullets=MAX_BULLETS))
    # Names the theme in the initramfs's file list, where install.sh's check
    # looks for it (lsinitramfs lists names, not contents).
    open(f"{out}/stub-{stub}", "w").write("")
    return p


def preview(stub, p, path, at=0.3):
    t = f"{HERE}/themes/{stub}"
    W, H = 1920, 1200
    img = background(stub).resize((W, H))
    d = ImageDraw.Draw(img)
    bx, by = (W - BAR_W) // 2, H // 2
    d.rectangle([bx, by, bx + BAR_W - 1, by + BAR_STRIPE - 1], fill=rgba(p["surf"]))
    sx = bx + int((BAR_W - SEGMENT_W) * at)
    d.rectangle([sx, by, sx + SEGMENT_W - 1, by + BAR_STRIPE - 1], fill=rgba(p["acc"]))
    lab = Image.open(f"{t}/label-boot.png")
    img.alpha_composite(lab, ((W - lab.width) // 2, by + LABEL_GAP - lab.height // 2))
    img.convert("RGB").save(path)


if __name__ == "__main__":
    want_preview = "--preview" in sys.argv
    outdir = os.environ.get("PLYMOUTH_PREVIEW_DIR", "/tmp/plymouth-theme-preview")
    if want_preview:
        os.makedirs(outdir, exist_ok=True)
    for stub in STUBS:
        p = generate(stub)
        print(f"plymouth/themes/{stub}")
        if want_preview:
            preview(stub, p, f"{outdir}/{stub}.png")
    if want_preview:
        print(f"previews in {outdir}")
