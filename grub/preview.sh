#!/usr/bin/env bash
# Boots a GRUB theme from grub/themes in real GRUB — a UEFI virtual machine
# (QEMU with OVMF) — and saves a screenshot, so a change to grub/generate.py
# can be seen before rebooting. GRUB lays themes out in ways a mock-up can't
# show: it draws the menu panel over anything inside it, makes a progress bar
# at least 28 px tall, and hides entries that don't fit when there's no
# scrollbar. The menu entries are this laptop's.
#
#   grub/preview.sh [STUB] [WxH ...]    e.g. grub/preview.sh gruvbox-dark 1920x1200 2560x1440
#
# Defaults: the current theme, at 1920x1200. A mode the virtual firmware
# doesn't offer falls back to 800x600, as it would on a real screen.
# Needs: qemu-system-x86 ovmf xorriso mtools (apt), grub-mkrescue (grub-common).
set -euo pipefail
GRUB_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
stub=${1:-}
if [[ -z "$stub" ]]; then
  read -r family variant < "$HOME/.config/theme/current"
  case $family in catppuccin) stub=$variant ;; gruvbox) stub=gruvbox-$variant ;; *) stub=$family ;; esac
fi
shift || true
modes=("${@:-1920x1200}")
theme="$GRUB_DIR/themes/$stub"
[[ -f "$theme/theme.txt" ]] || { echo "no theme at $theme" >&2; exit 1; }
for b in qemu-system-x86_64 grub-mkrescue grub-mkfont xorriso mformat; do
  command -v "$b" >/dev/null || { echo "$b missing — sudo apt install qemu-system-x86 ovmf xorriso mtools" >&2; exit 1; }
done
ovmf=/usr/share/OVMF/OVMF_CODE_4M.fd
[[ -f $ovmf ]] || { echo "OVMF missing — sudo apt install ovmf" >&2; exit 1; }

out=${GRUB_PREVIEW_DIR:-/tmp/grub-theme-preview}
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
mkdir -p "$out" "$work/iso/boot/grub/themes"
t="$work/iso/boot/grub/themes/test"
cp -r "$theme" "$t"
cp /usr/share/grub/unicode.pf2 "$t/font.pf2"
for sz in 16 20; do   # the same fonts install.sh makes
  grub-mkfont -s "$sz" -r 0x20-0x7E -r 0xA0-0x17F -r 0x2190-0x2193 -o "$t/fira-$sz.pf2" \
    "$HOME/.local/share/fonts/FiraCodeNerdFont-Regular.ttf"
done

for m in "${modes[@]}"; do
  cat > "$work/iso/boot/grub/grub.cfg" <<EOF
insmod all_video
insmod gfxterm
insmod png
set gfxmode=$m,auto
terminal_output gfxterm
loadfont /boot/grub/themes/test/font.pf2
loadfont /boot/grub/themes/test/fira-16.pf2
loadfont /boot/grub/themes/test/fira-20.pf2
set theme=/boot/grub/themes/test/theme.txt
export theme
set timeout=30
menuentry 'Ubuntu' --class ubuntu --class gnu-linux --class gnu --class os { true }
submenu 'Advanced options for Ubuntu' { menuentry 'Ubuntu, with Linux' { true } }
menuentry 'Windows Boot Manager (on /dev/nvme0n1p1)' --class windows --class os { true }
menuentry 'UEFI Firmware Settings' { fwsetup }
EOF
  grub-mkrescue -o "$work/test.iso" "$work/iso" --modules="png gfxterm all_video" >/dev/null 2>&1
  cp /usr/share/OVMF/OVMF_VARS_4M.fd "$work/vars.fd"
  # GRUB is up a few seconds after power-on; the screenshot is taken at 12 s.
  ( sleep 12; echo "screendump $work/shot.ppm"; sleep 2; echo quit ) \
    | timeout 90 qemu-system-x86_64 -m 512 -machine q35 \
        -drive if=pflash,format=raw,readonly=on,file="$ovmf" -drive if=pflash,format=raw,file="$work/vars.fd" \
        -device VGA,edid=on,xres="${m%x*}",yres="${m#*x}" -cdrom "$work/test.iso" \
        -display none -monitor stdio >/dev/null 2>&1
  python3 -I -c 'import sys; from PIL import Image; Image.open(sys.argv[1]).save(sys.argv[2])' \
    "$work/shot.ppm" "$out/$stub-$m.png"
  echo "$out/$stub-$m.png"
done
