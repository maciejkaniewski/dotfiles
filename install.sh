#!/usr/bin/env bash

# ── Catppuccin Frappé palette ──────────────────────────────────────────────────
MAUVE='\033[38;2;202;158;230m'
GREEN='\033[38;2;166;209;137m'
RED='\033[38;2;231;130;132m'
YELLOW='\033[38;2;229;200;144m'
BLUE='\033[38;2;140;170;238m'
TEAL='\033[38;2;129;200;190m'
TEXT='\033[38;2;198;208;245m'
SUBTEXT='\033[38;2;165;173;206m'
BOLD='\033[1m'
RESET='\033[0m'

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# uv, the uv tools and Claude Code install into ~/.local/bin, and later
# steps of the same run call them. A fresh account's login shell puts that
# directory on PATH only if it existed at login, which on a first run it didn't.
[[ ":$PATH:" == *":$HOME/.local/bin:"* ]] || export PATH="$HOME/.local/bin:$PATH"

NEED_RESTART=false
FAIL_COUNT=0
SUDO_KEEPALIVE_PID=""
SPIN_FRAMES=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
# Sat by run_spin/run_spin_capture when the command they ran fails; log_error
# prints it as trailing detail right after its own line, then clears it. Every
# other log_* clears it unconsumed — a spin failure's detail is only ever
# relevant to the very next status line, never to some later, unrelated one.
SPIN_ERR_DETAIL=""

# One temp directory for the whole run, removed by the trap below. run_spin and
# run_spin_capture used to mktemp straight into /tmp and unlink at the end of
# their own call, so a Ctrl-C mid-spinner orphaned the scratch file — a handful
# of stray /tmp/tmp.* files accumulated over a few interrupted runs. Anchoring
# every scratch file under one directory makes cleanup a single rm -rf that a
# trap can do from anywhere.
#
# Deliberately does NOT kill background children: run_spin backgrounds things
# like `apt-get install`, and interrupting dpkg mid-transaction leaves the
# package database in a far worse state than a leaked temp file.
SCRIPT_TMPDIR=$(mktemp -d)
cleanup_tmp() {
  [[ -n "$SCRIPT_TMPDIR" && -d "$SCRIPT_TMPDIR" ]] && rm -rf "$SCRIPT_TMPDIR"
  return 0   # never let cleanup influence the script's exit status
}
trap cleanup_tmp EXIT
trap 'cleanup_tmp; exit 130' INT
trap 'cleanup_tmp; exit 143' TERM

# ── Helpers ────────────────────────────────────────────────────────────────────
# Every line below starts with \r\033[K (return to column 0, clear to end of
# line) before its content. Without it, a plain `echo`'s trailing newline can
# leave the cursor wherever the previous line's text happened to end instead
# of column 0 — some terminal states don't auto-CR on LF — and every line
# after that silently drifts further right, staircasing down the screen. Only
# run_spin's own spinner redraws did this before; these did not, which is why
# corruption only showed up starting from the first log line not preceded by
# a spinner.

section()      { SPIN_ERR_DETAIL=""; echo -e "\r\033[K"; echo -e "\r\033[K  ${BLUE}${BOLD}$1${RESET}"; }
log_ok()       { SPIN_ERR_DETAIL=""; echo -e "\r\033[K  ${GREEN}✓${RESET}  ${TEXT}$1${RESET}"; }
log_skip()     { SPIN_ERR_DETAIL=""; echo -e "\r\033[K  ${TEAL}~${RESET}  ${SUBTEXT}$1${RESET}"; }
log_linked()   { SPIN_ERR_DETAIL=""; echo -e "\r\033[K  ${GREEN}✓${RESET}  ${TEXT}$1${RESET}"; }
log_unlinked() { SPIN_ERR_DETAIL=""; echo -e "\r\033[K  ${RED}−${RESET}  ${SUBTEXT}$1${RESET}"; }
log_skip_link(){ SPIN_ERR_DETAIL=""; echo -e "\r\033[K  ${TEAL}~${RESET}  ${SUBTEXT}$1${RESET}"; }
log_exists()   { SPIN_ERR_DETAIL=""; echo -e "\r\033[K  ${YELLOW}!${RESET}  ${SUBTEXT}$1 — remove manually to relink${RESET}"; }
log_detail()   { echo -e "\r\033[K     ${SUBTEXT}↳ $1${RESET}"; }
log_warn()     { SPIN_ERR_DETAIL=""; echo -e "\r\033[K  ${YELLOW}!${RESET}  ${TEXT}$1${RESET}"; }
# Counts toward the end-of-run failure summary and the script's exit code.
# Prints any pending run_spin failure detail as trailing lines, so it reads as
# belonging to THIS failure instead of whatever line happened to precede it.
log_error() {
  echo -e "\r\033[K  ${RED}✗${RESET}  ${TEXT}$1 — ${RED}$2${RESET}"
  (( FAIL_COUNT++ )) || true
  if [[ -n "$SPIN_ERR_DETAIL" ]]; then
    while IFS= read -r line; do log_detail "$line"; done <<< "$SPIN_ERR_DETAIL"
    SPIN_ERR_DETAIL=""
  fi
}

command_exists() { command -v "$1" &>/dev/null; }

# Whether a deb package is installed. Not `dpkg -s`: that also succeeds for a
# package that was removed but kept its config files ("rc", the state
# `apt remove` leaves), so a removed package looked installed: it was never
# reinstalled, and ser2net's --verify check could not pass after its removal.
pkg_installed() { [[ $(dpkg-query -W -f='${db:Status-Status}' "$1" 2>/dev/null) == installed ]]; }

# The header every command opens with. Ends with the version of the repo the
# run used: the tag on HEAD (v1.0.0), or past one the commits since and the
# hash (v1.0.0-3-gabc1234), or just the hash before any tag. Left off when
# there is no git history to ask (a downloaded archive).
banner() {
  local version
  version=$(git -C "$DOTFILES" describe --tags --always 2>/dev/null)
  echo -e "\r\033[K  ${MAUVE}${BOLD}dotfiles${RESET} ${SUBTEXT}· Maciej Kaniewski${version:+ · ${version}}${RESET}"
}

# Forces the terminal back to a known-good input mode right before a `read`
# that needs one. Something intermittent earlier in --setup (apt/dpkg
# maintainer scripts, most likely — never pinned down to one exact line, and
# not reliably reproducible standalone) can occasionally leave the pty
# without icrnl, so Enter's raw \r never satisfies read's newline terminator
# and the prompt hangs forever with no visible sign anything is wrong. Rather
# than depending on nothing upstream having broken it, just fix it again here.
reset_tty_for_read() { [[ -t 0 ]] && stty sane 2>/dev/null; }

# Runs a command with a spinner, prints ok/error when done. On failure, the
# last few lines of stderr are stashed in SPIN_ERR_DETAIL for log_error to
# print right after its own line, rather than printed here — printing them
# immediately would land them BEFORE the caller's log_ok/log_error line (which
# only runs once run_spin returns), visually attaching the error to whatever
# status line came before this one instead of the failure it actually belongs to.
# Usage: run_spin "label" cmd [args...]
run_spin() {
  local label="$1"; shift
  local i=0 errfile; errfile=$(mktemp -p "$SCRIPT_TMPDIR")
  SPIN_ERR_DETAIL=""

  "$@" >/dev/null 2>"$errfile" &
  local pid=$!

  while kill -0 "$pid" 2>/dev/null; do
    printf "\r  ${MAUVE}%s${RESET}  ${SUBTEXT}%s${RESET}" "${SPIN_FRAMES[$i]}" "$label"
    i=$(( (i + 1) % ${#SPIN_FRAMES[@]} ))
    sleep 0.1
  done

  wait "$pid"
  local rc=$?
  printf "\r\033[K"
  if (( rc != 0 )) && [[ -s "$errfile" ]]; then
    SPIN_ERR_DETAIL="$(tail -5 "$errfile")"
  fi
  rm -f "$errfile"
  return $rc
}

github_latest() {
  curl -fsIL "https://github.com/$1/releases/latest" 2>/dev/null \
    | grep -i "^location:" \
    | grep -oP '\d+\.\d+\.\d+'
}

# Like github_latest, but the Arm GNU Toolchain isn't on GitHub — its releases
# are GitLab branches named "releases/X.Y.relN" in this project.
arm_gcc_latest() {
  curl -fsSL "https://gitlab.arm.com/api/v4/projects/tooling%2Fgnu-toolchains-for-arm/repository/branches?search=releases/&per_page=100" 2>/dev/null \
    | grep -oP '"name":"releases/\K[^"]+' \
    | sort -V | tail -1
}

# glab isn't on GitHub either — gitlab.com serves its latest release as JSON.
glab_latest() {
  curl -fsSL "https://gitlab.com/api/v4/projects/gitlab-org%2Fcli/releases/permalink/latest" 2>/dev/null \
    | grep -oP '"tag_name":"v\K\d+\.\d+\.\d+'
}

# Like run_spin but captures stdout into a variable
# Usage: run_spin_capture "label" varname cmd [args...]
run_spin_capture() {
  local label="$1" outvar="$2"; shift 2
  local i=0 tmpfile errfile; tmpfile=$(mktemp -p "$SCRIPT_TMPDIR"); errfile=$(mktemp -p "$SCRIPT_TMPDIR")
  SPIN_ERR_DETAIL=""

  "$@" > "$tmpfile" 2>"$errfile" &
  local pid=$!

  while kill -0 "$pid" 2>/dev/null; do
    printf "\r  ${MAUVE}%s${RESET}  ${SUBTEXT}%s${RESET}" "${SPIN_FRAMES[$i]}" "$label"
    i=$(( (i + 1) % ${#SPIN_FRAMES[@]} ))
    sleep 0.1
  done

  wait "$pid"; local rc=$?
  printf "\r\033[K"
  if (( rc != 0 )) && [[ -s "$errfile" ]]; then
    SPIN_ERR_DETAIL="$(tail -5 "$errfile")"
  fi
  printf -v "$outvar" '%s' "$(cat "$tmpfile")"
  rm -f "$tmpfile" "$errfile"
  return $rc
}

# Formats a byte count as a human-readable size, 1024-based so the numbers
# agree with what `ls -lh`/`du -h` report for the same file once it lands.
# Pure shell arithmetic on purpose: this is called several times per spinner
# frame, and forking awk/numfmt for each one made the redraw visibly stutter.
human_bytes() {
  local b=${1:-0} u=0 frac=0
  local -a units=(B KiB MiB GiB TiB)
  while (( b >= 1024 && u < 4 )); do
    frac=$(( (b % 1024) * 10 / 1024 ))
    b=$(( b / 1024 ))
    (( u++ ))
  done
  if (( u == 0 )); then printf '%d %s' "$b" "${units[u]}"
  else printf '%d.%d %s' "$b" "$frac" "${units[u]}"; fi
}

# Resolves a download's real size from its Content-Length. -L matters: GitHub
# release URLs redirect to a CDN host, and only the final header block carries
# the true length (the 302's own is 0), hence resetting at each status line so
# what's left at EOF is the final response's.
#
# The 2xx guard is not paranoia: a 404 from GitHub still carries a
# Content-Length (9, for its "Not Found" body), which would otherwise be
# reported as the download size and make the progress bar meaningless. Prints
# nothing on any non-success, which callers must read as "size unknown" rather
# than as zero.
remote_size() {
  curl -fsIL --max-time 20 "$1" 2>/dev/null \
    | tr -d '\r' \
    | awk '
        /^[Hh][Tt][Tt][Pp]\// { status = $2; n = ""; next }
        tolower($1) == "content-length:" { n = $2 }
        END { if (status ~ /^2/ && n != "") print n }
      '
}

# Current terminal width, falling back to a conservative 80 when there's no
# tty (piped output, CI) or terminfo won't say. Callers budget against
# cols-1 rather than cols: writing the final column leaves some terminals in
# a pending-wrap state that wraps on the very next character written.
term_cols() {
  local c; c=$(tput cols 2>/dev/null)
  if [[ "$c" =~ ^[0-9]+$ ]] && (( c > 0 )); then printf '%s' "$c"; else printf '80'; fi
}

# Truncates a label to at most $2 columns, marking the cut with an ellipsis so
# a shortened label reads as shortened rather than as a typo.
fit_label() {
  local s="$1" max="$2"
  if (( max < 1 )); then return; fi
  if (( ${#s} > max )); then printf '%s…' "${s:0:$(( max - 1 ))}"; else printf '%s' "$s"; fi
}

# Like run_spin, but for a single large download: draws a real progress bar fed
# by the growing output file instead of a bare spinner. Past a few hundred MB a
# spinner is indistinguishable from a hang for minutes at a time, which is
# exactly when you most want to know whether to wait or kill it.
#
# The total comes from remote_size; when that's unavailable it degrades to
# spinner + bytes-so-far rather than inventing a denominator, because a bar
# that can't reach 100% is worse than no bar. The rate is a running average
# over the whole transfer, not instantaneous — steadier to read, and the ETA
# it implies is the one that matters for a file this size.
# Usage: run_spin_download "label" url outfile
run_spin_download() {
  local label="$1" url="$2" out="$3"
  local i=0 errfile; errfile=$(mktemp -p "$SCRIPT_TMPDIR")
  SPIN_ERR_DETAIL=""

  # Something on screen before the blocking HEAD below, which can take a
  # second or two on a cold connection. Width-guarded like every other line
  # here — 5 fixed columns of indent + spinner + gap, so the label gets cols-6.
  local cols; cols=$(term_cols)
  local lbl; lbl=$(fit_label "$label" $(( cols - 6 )))
  printf "\r\033[K  ${MAUVE}%s${RESET}  ${SUBTEXT}%s${RESET}" "${SPIN_FRAMES[0]}" "$lbl"
  local total; total=$(remote_size "$url")
  local totalh; totalh=$(human_bytes "${total:-0}")

  # A stale file here would otherwise be measured as instant progress for the
  # moment before curl truncates it — e.g. a previous run's cancelled partial
  # reading as 100% on the first frame.
  rm -f "$out"
  curl -fsSL "$url" -o "$out" 2>"$errfile" &
  local pid=$!

  local start=$SECONDS

  # The whole line MUST fit the terminal. If it doesn't, the terminal wraps it
  # and the \r above only returns to the start of the LAST visual row — so
  # every redraw lands on a fresh row and the in-place spinner becomes a
  # staircase of every frame it ever drew. Re-read per frame rather than once,
  # so resizing the window mid-download stays correct.
  #
  local bar_max=24
  while kill -0 "$pid" 2>/dev/null; do
    cols=$(term_cols)
    lbl=$(fit_label "$label" $(( cols - 6 )))

    # Guard the empty case: curl hasn't necessarily created the file by the
    # first frame, and an empty string here would break the arithmetic below.
    local cur=0
    if [[ -f "$out" ]]; then cur=$(stat -c %s "$out" 2>/dev/null); fi
    [[ -n "$cur" ]] || cur=0
    local elapsed=$(( SECONDS - start )); (( elapsed < 1 )) && elapsed=1
    local frame="${SPIN_FRAMES[$i]}"
    local curh rateh
    curh=$(human_bytes "$cur")
    rateh=$(human_bytes $(( cur / elapsed )))

    if [[ -n "$total" ]] && (( total > 0 )); then
      local pct=$(( cur * 100 / total )); (( pct > 100 )) && pct=100
      local pctstr; printf -v pctstr '%3d%%' "$pct"

      # Widest layout that fits, shedding detail in order of expendability:
      # rate first, then the bar, then the counters, then the label. Percent
      # is the last thing standing — it's the reason the line exists. Fixed
      # cost is 9 columns: 2 indent + 1 spinner + 2 gap + 2 before the bar
      # + 2 after it.
      local counters="${curh} / ${totalh}  ${rateh}/s"
      local barw=$(( cols - 1 - 9 - ${#lbl} - ${#pctstr} - 2 - ${#counters} ))
      if (( barw < 8 )); then
        counters="${curh} / ${totalh}"
        barw=$(( cols - 1 - 9 - ${#lbl} - ${#pctstr} - 2 - ${#counters} ))
      fi
      (( barw > bar_max )) && barw=$bar_max

      if (( barw >= 8 )); then
        local filled=$(( pct * barw / 100 )) bar rest
        printf -v bar  '%*s' "$filled"            ''; bar="${bar// /█}"
        printf -v rest '%*s' $(( barw - filled )) ''; rest="${rest// /░}"
        printf "\r\033[K  ${MAUVE}%s${RESET}  ${SUBTEXT}%s${RESET}  ${MAUVE}%s${SUBTEXT}%s${RESET}  ${TEXT}%s${RESET}  ${SUBTEXT}%s${RESET}" \
          "$frame" "$lbl" "$bar" "$rest" "$pctstr" "$counters"
      elif (( 5 + ${#lbl} + 2 + ${#pctstr} + 2 + ${#counters} <= cols - 1 )); then
        printf "\r\033[K  ${MAUVE}%s${RESET}  ${SUBTEXT}%s${RESET}  ${TEXT}%s${RESET}  ${SUBTEXT}%s${RESET}" \
          "$frame" "$lbl" "$pctstr" "$counters"
      elif (( 5 + ${#lbl} + 2 + ${#pctstr} <= cols - 1 )); then
        printf "\r\033[K  ${MAUVE}%s${RESET}  ${SUBTEXT}%s${RESET}  ${TEXT}%s${RESET}" \
          "$frame" "$lbl" "$pctstr"
      else
        printf "\r\033[K  ${MAUVE}%s${RESET}  ${TEXT}%s${RESET}" "$frame" "$pctstr"
      fi
    else
      # Size unknown: bytes-so-far only, no invented denominator. Same
      # shed-to-fit discipline as the sized layouts above.
      local info="${curh} at ${rateh}/s"
      if (( 5 + ${#lbl} + 2 + ${#info} <= cols - 1 )); then
        printf "\r\033[K  ${MAUVE}%s${RESET}  ${SUBTEXT}%s  %s${RESET}" "$frame" "$lbl" "$info"
      elif (( 5 + ${#lbl} + 2 + ${#curh} <= cols - 1 )); then
        printf "\r\033[K  ${MAUVE}%s${RESET}  ${SUBTEXT}%s  %s${RESET}" "$frame" "$lbl" "$curh"
      else
        printf "\r\033[K  ${MAUVE}%s${RESET}  ${SUBTEXT}%s${RESET}" "$frame" "$curh"
      fi
    fi
    i=$(( (i + 1) % ${#SPIN_FRAMES[@]} ))
    sleep 0.2
  done

  wait "$pid"
  local rc=$?
  printf "\r\033[K"
  if (( rc != 0 )) && [[ -s "$errfile" ]]; then
    SPIN_ERR_DETAIL="$(tail -5 "$errfile")"
  fi
  rm -f "$errfile"
  return $rc
}

# Returns 0 (true) if $1 < $2 using version sort
version_lt() {
  [[ "$(printf '%s\n' "$1" "$2" | sort -V | head -1)" == "$1" && "$1" != "$2" ]]
}

# Version uv has installed for a `uv tool` package, empty when uv doesn't manage
# it. `uv tool list` prints "name vX.Y.Z" then one "- executable" line per entry
# point; only the first kind has the package name in column 1.
uv_tool_version() {
  uv tool list 2>/dev/null | awk -v p="$1" '$1 == p { sub(/^v/, "", $2); print $2 }'
}

# ── Tool versions ──────────────────────────────────────────────────────────────
# The repo's versions file names the exact version --setup installs for each
# tool it lists, so every machine builds and formats alike. A key in
# ~/.config/dotfiles/versions overrides it on one machine, and "latest" in
# either file tracks upstream instead.
VERSIONS_FILE="$DOTFILES/versions"
VERSIONS_LOCAL="$HOME/.config/dotfiles/versions"

# Prints the pinned version for key $1, or nothing when it tracks latest.
tool_pin() {
  local f v=""
  for f in "$VERSIONS_LOCAL" "$VERSIONS_FILE"; do
    [[ -f "$f" ]] || continue
    v=$(awk -F= -v k="$1" '{ sub(/#.*/, ""); gsub(/[[:space:]]/, "") } $1 == k { print $2; exit }' "$f")
    [[ -n "$v" ]] && break
  done
  [[ "$v" == latest ]] || printf '%s' "$v"
}

# The installed version of a pinnable tool, in the spelling the versions file
# uses, or nothing when it isn't installed. The Arm toolchain is read from its
# own path first: /opt/arm-gcc/bin reaches PATH only through the
# /usr/local/bin links this script makes.
tool_installed_version() {
  local armgcc=/opt/arm-gcc/bin/arm-none-eabi-gcc v=""
  case "$1" in
    arm-gcc)
      [[ -x "$armgcc" ]] || armgcc=$(command -v arm-none-eabi-gcc)
      [[ -n "$armgcc" ]] && v=$("$armgcc" --version 2>/dev/null | head -1 | grep -ioP '\d+\.\d+\.rel\d+') ;;
    cmake) command_exists cmake && v=$(cmake --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+') ;;
    ninja) command_exists ninja && v=$(ninja --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+') ;;
    uv)    command_exists uv && v=$(uv --version 2>/dev/null | awk '{print $2}') ;;
    clang) command_exists clang && v=$(clang -dumpversion 2>/dev/null | cut -d. -f1) ;;
  esac
  printf '%s' "${v,,}"
}

# Whether a tool needs installing: $1 label, $2 installed version (empty when
# none), $3 target version, $4 non-empty when the target is a pin. A pin is met
# only by that exact version, so it can move down as well as up; otherwise only
# a newer release counts. Logs the skip or the move; returns 1 for a skip.
needs_install() {
  local label="$1" have="$2" want="$3" pinned="$4"
  [[ -n "$have" ]] || return 0
  if [[ -n "$pinned" ]]; then
    [[ "$have" == "$want" ]] && { log_skip "$label $have (pinned)"; return 1; }
    log_warn "$label $have → switching to pinned $want"
    return 0
  fi
  version_lt "$have" "$want" || { log_skip "$label $have"; return 1; }
  log_warn "$label $have → upgrading to $want"
}

# Mason is no longer part of the Neovim config: lua-language-server, the one
# tool it still installed, now comes from install_lua_language_server. Its
# packages under ~/.local/share/nvim/mason are dead weight, and a ~/.local/bin
# shim into them would shadow the copy install.sh puts on PATH.
remove_mason() {
  local mason="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/mason" shim
  for shim in "$HOME"/.local/bin/*; do
    if [[ -L "$shim" && "$(readlink "$shim")" == *"/nvim/mason/"* ]]; then
      rm -f "$shim" && log_ok "removed stale Mason shim ~/.local/bin/${shim##*/}"
    fi
  done
  [[ -d "$mason" ]] || return 0
  rm -rf "${mason:?}" && log_ok "removed Mason's packages (the Neovim config no longer uses Mason)"
}

# Wraps `sudo apt-get`, forcing the noninteractive frontend and telling
# needrestart to restart services automatically instead of asking. `sudo`
# resets the environment by default, so these have to be passed through `env`
# rather than just exported — without them, a debconf prompt (needrestart's
# "which services should be restarted?" dialog is the usual offender on
# Ubuntu) can open its own whiptail/ncurses UI on /dev/tty. Since run_spin
# redirects the command's stdout/stderr but leaves stdin on the real
# terminal, that dialog fights the spinner for the tty and can leave it in a
# corrupted, jumbled-output state.
apt_get() {
  sudo env "DEBIAN_FRONTEND=noninteractive" "NEEDRESTART_MODE=a" apt-get "$@"
}

# ── Release architecture ─────────────────────────────────────────────────────────
# Each upstream names the same CPU arch differently in its release assets; resolve
# every variant once so the download URLs below work on both amd64 and arm64.
# ARCH_GENERIC covers the common "x86_64"/"aarch64" Rust-target-style naming shared
# by StyLua, ripgrep, fd, zoxide, cmake and btop's release assets.
case "$(dpkg --print-architecture 2>/dev/null || uname -m)" in
  arm64 | aarch64)
    ARCH_DEB=arm64;  ARCH_FZF=arm64;  ARCH_LG=arm64;  ARCH_GENERIC=aarch64;  ARCH_NVIM=arm64;  ARCH_TS=arm64
    ARCH_EZA=aarch64-unknown-linux-gnu;  ARCH_NINJA="-aarch64";  ARCH_LLVM=ARM64;  ARCH_LUALS=arm64;  ARCH_DIFFT=aarch64-unknown-linux-gnu ;;
  *)  # amd64/x86_64 (and anything unrecognized) falls back to the common desktop arch
    ARCH_DEB=amd64;  ARCH_FZF=amd64;  ARCH_LG=x86_64;  ARCH_GENERIC=x86_64;   ARCH_NVIM=x86_64;  ARCH_TS=x64
    ARCH_EZA=x86_64-unknown-linux-gnu;   ARCH_NINJA="";  ARCH_LLVM=X64;  ARCH_LUALS=x64;  ARCH_DIFFT=x86_64-unknown-linux-musl ;;
esac

# ── Symlink table ──────────────────────────────────────────────────────────────
# Each entry is "Section|src:dst". Section groups the entry under a header
# when cmd_link prints its per-tool sections; cmd_setup and cmd_clean just
# iterate the whole table under one header. One table, so adding or removing a
# symlink can't leave --link and --setup out of sync with each other.

LINKS=(
  "Shell|$DOTFILES/.zshrc:$HOME/.zshrc"
  "Shell|$DOTFILES/.p10k.zsh:$HOME/.p10k.zsh"
  "Git|$DOTFILES/.gitconfig:$HOME/.gitconfig"
  "Git|$DOTFILES/.local/bin/git-credential-bw:$HOME/.local/bin/git-credential-bw"
  "Utilities|$DOTFILES/.local/bin/ports:$HOME/.local/bin/ports"
  "SSH|$DOTFILES/.ssh/config:$HOME/.ssh/config"
  "Kitty|$DOTFILES/.config/kitty/kitty.conf:$HOME/.config/kitty/kitty.conf"
  "Kitty|$DOTFILES/.config/kitty/tab_bar.py:$HOME/.config/kitty/tab_bar.py"
  "Kitty|$DOTFILES/.config/kitty/ssh.conf:$HOME/.config/kitty/ssh.conf"
  "Neovim|$DOTFILES/.config/nvim/init.lua:$HOME/.config/nvim/init.lua"
  "Neovim|$DOTFILES/.config/nvim/lazy-lock.json:$HOME/.config/nvim/lazy-lock.json"
  "Neovim|$DOTFILES/.config/nvim/stylua.toml:$HOME/.config/nvim/stylua.toml"
  "Neovim|$DOTFILES/.config/nvim/lua:$HOME/.config/nvim/lua"
  "Claude|$DOTFILES/.claude/statusline-git.sh:$HOME/.claude/statusline-git.sh"
  "Claude|$DOTFILES/.claude/nvim-checktime.sh:$HOME/.claude/nvim-checktime.sh"
  "Utilities|$DOTFILES/.config/bat/themes:$HOME/.config/bat/themes"
  "Utilities|$DOTFILES/.config/delta/catppuccin.gitconfig:$HOME/.config/delta/catppuccin.gitconfig"
  "Utilities|$DOTFILES/.config/delta/gruvbox.gitconfig:$HOME/.config/delta/gruvbox.gitconfig"
  "Utilities|$DOTFILES/.config/delta/dracula.gitconfig:$HOME/.config/delta/dracula.gitconfig"
  "Utilities|$DOTFILES/.config/lazygit/config.yml:$HOME/.config/lazygit/config.yml"
  "Utilities|$DOTFILES/.config/yazi/keymap.toml:$HOME/.config/yazi/keymap.toml"
  "Utilities|$DOTFILES/.config/yazi/plugins/smart-enter.yazi:$HOME/.config/yazi/plugins/smart-enter.yazi"
  "Utilities|$DOTFILES/.config/yazi/flavors:$HOME/.config/yazi/flavors"
)

# Splits a "Section|src:dst" entry into its three parts.
# Usage: link_parts "$entry" section_var src_var dst_var
link_parts() {
  local entry="$1" rest="${1#*|}"
  printf -v "$2" '%s' "${entry%%|*}"
  printf -v "$3" '%s' "${rest%%:*}"
  printf -v "$4" '%s' "${rest##*:}"
}

# Claude Code writes /model, /config and theme changes into
# ~/.claude/settings.json, so symlinking that file into the repo kept dirtying
# the repo with per-machine choices. The repo now holds only the stable part
# (.claude/settings.base.json: env, hooks, status line, plugins) and this
# overlays it onto the live file as a plain local file. Keys the repo doesn't
# set (model, effort, theme, permissions, ...) stay exactly as that machine has
# them; keys it does set win, so changing a hook means editing the repo file and
# re-running install. A legacy symlink is replaced by its contents, or by just
# the base when it dangles (the repo file it pointed at no longer exists).
merge_claude_settings() {
  local base="$DOTFILES/.claude/settings.base.json" dst="$HOME/.claude/settings.json"
  local name="${dst#"$HOME/"}" live merged tmp
  [[ -f "$base" ]] || return
  command_exists jq || { log_error "$name" "jq is required to merge the Claude settings (run --setup)"; return; }
  mkdir -p "$(dirname "$dst")"

  live='{}'
  [[ -f "$dst" ]] && live=$(cat "$dst")
  [[ -n "${live//[[:space:]]/}" ]] || live='{}'
  jq -e 'type == "object"' <<<"$live" &>/dev/null \
    || { log_error "$name" "is not a JSON object — fix or remove it, then re-run"; return; }

  merged=$(jq -s '.[0] * .[1]' <(printf '%s' "$live") "$base") \
    || { log_error "$name" "merge failed"; return; }

  if [[ -f "$dst" && ! -L "$dst" ]] && [[ "$(jq -S . "$dst")" == "$(jq -S . <<<"$merged")" ]]; then
    log_skip_link "$name (already merged)"; return
  fi
  tmp=$(mktemp "$dst.XXXXXX") \
    && printf '%s\n' "$merged" > "$tmp" \
    && mv -f "$tmp" "$dst" \
    && log_linked "$name (repo base merged, local keys kept)" \
    || { rm -f "$tmp"; log_error "$name" "could not write"; }
}

# ssh refuses a config file that group or others can write ("Bad owner or
# permissions") and checks the file a symlink points to. git records only the
# executable bit, so under Ubuntu's umask 002 the repo's .ssh/config checks out
# group-writable. ~/.ssh itself must not be group-writable either (sshd then
# ignores authorized_keys), and make_link's mkdir -p would create it that way.
fix_ssh_modes() {
  [[ -d "$HOME/.ssh" ]] && chmod 700 "$HOME/.ssh"
  chmod go-w "$DOTFILES/.ssh/config"
}

# The desktop session, GNOME or niri, starts through a zsh login shell, which
# reads ~/.zprofile but never ~/.zshrc. So what the session launches directly
# (niri's Super+T kitty, kitty -e yazi) finds only what ~/.zprofile puts on
# PATH; ~/.zshrc's entries reach interactive shells alone. ~/.zprofile stays
# machine-local (other installers append to it too), so this adds one marked
# line rather than linking the file.
ensure_login_path() {
  local zprofile="$HOME/.zprofile" marker="# dotfiles: login-session PATH"
  if grep -qF "$marker" "$zprofile" 2>/dev/null; then
    log_skip_link ".zprofile (login-session PATH already set)"; return
  fi
  printf '\n%s (see ensure_login_path in install.sh)\nexport PATH="$HOME/.local/kitty.app/bin:$HOME/.local/bin:$PATH"\n' "$marker" >> "$zprofile" \
    && log_linked ".zprofile (kitty and ~/.local/bin on the login-session PATH)" \
    || log_error ".zprofile" "could not append the PATH line"
}

make_link() {
  local src="$1" dst="$2"
  local name="${dst#"$HOME/"}"
  if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
    log_skip_link "$name (already linked)"; return
  fi
  if [[ -e "$dst" || -L "$dst" ]]; then
    printf "\r\033[K  ${YELLOW}!${RESET}  ${TEXT}%s already exists — replace with symlink? [y/N] ${RESET}" "$name"
    local reply
    reset_tty_for_read
    read -r reply
    if [[ "$reply" =~ ^[Yy]$ ]]; then
      local real_dst real_src
      real_dst="$(realpath "$dst" 2>/dev/null)"
      real_src="$(realpath "$src" 2>/dev/null)"
      if [[ -n "$real_dst" && "$real_dst" == "$real_src" ]]; then
        log_error "$name" "dst resolves to src — refusing to delete repo file"; return
      fi
      rm -rf "$dst"
    else
      log_skip "$name (kept existing)"; return
    fi
  fi
  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst" && log_linked "$name" || log_error "$name" "failed to create symlink"
}

remove_link() {
  local src="$1" dst="$2"
  local name="${dst#"$HOME/"}"
  if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
    rm "$dst" && log_unlinked "$name"
  fi
}

# ── Installers ─────────────────────────────────────────────────────────────────

# git from the git-core PPA, which follows upstream releases: Ubuntu's own git
# stays at the version the release shipped with (2.43 on 24.04, 2.53 on 26.04).
# The PPA builds for every supported Ubuntu release. -n skips the PPA's own
# apt update, since install_apt_packages runs one right after; its upgrade step
# then moves an installed git to the PPA's version.
add_git_ppa() {
  if compgen -G "/etc/apt/sources.list.d/git-core-ubuntu-ppa-*" >/dev/null; then
    log_skip "git-core PPA"; return
  fi
  if ! command_exists add-apt-repository; then
    run_spin "installing software-properties-common..." apt_get install -y software-properties-common \
      || { log_error "git-core PPA" "add-apt-repository is missing and could not be installed"; return; }
  fi
  run_spin "adding the git-core PPA..." sudo env DEBIAN_FRONTEND=noninteractive add-apt-repository -y -n ppa:git-core/ppa \
    && log_ok "git-core PPA (git follows upstream releases)" \
    || log_error "git-core PPA" "could not add ppa:git-core/ppa"
}

install_apt_packages() {
  section "System update"

  # run_spin hides sudo's password prompt behind the spinner (stderr → /dev/null),
  # so prime the credential visibly here, then keep it warm for the whole run —
  # long apt/dpkg steps can otherwise outlast sudo's timestamp and re-prompt blind.
  if ! sudo -v; then
    log_error "sudo" "authentication failed — cannot continue"; return 1
  fi
  ( while kill -0 "$$" 2>/dev/null; do sudo -n true; sleep 50; done ) &>/dev/null &
  SUDO_KEEPALIVE_PID=$!

  add_git_ppa

  run_spin "fetching package lists..." apt_get update -qq \
    && log_ok "package lists up to date" || log_error "apt" "update failed — network down? re-run ./install.sh --setup once it is back"
  run_spin "upgrading installed packages..." apt_get upgrade -y -qq \
    && log_ok "all packages upgraded to latest" || log_error "apt" "upgrade failed — network down? re-run ./install.sh --setup once it is back"

  section "System packages"

  local pkgs=(
    "build-essential:Base compilation tools (make, libc-dev)"
    "curl:Command-line HTTP client"
    "fonts-symbola:Unicode symbols font, required for correct symbols in Claude CLI"
    "g++:GNU C++ compiler"
    "gcc:GNU C compiler"
    "git:Version control system"
    "git-lfs:Git Large File Storage, for repos that keep binaries in LFS"
    "libxkbcommon-x11-0:X11 keyboard library the prebuilt Kitty loads to open a window"
    "python3-dev:Python headers and libpython, for building Rust/C Python extensions"
    "tree:Display directory structure as a tree"
    "unzip:Extract ZIP archives, used to install fonts and StyLua"
    "valgrind:Memory error detector and profiler"
    "wget:Command-line file downloader"
    "zsh:Z shell"
  )

  local max=0
  for entry in "${pkgs[@]}"; do
    local pkg="${entry%%:*}"
    (( ${#pkg} > max )) && max=${#pkg}
  done

  for entry in "${pkgs[@]}"; do
    local pkg="${entry%%:*}"
    local desc="${entry##*:}"
    local label; label=$(printf "%-${max}s" "$pkg")
    if pkg_installed "$pkg"; then
      log_skip "$label — $desc"
    else
      run_spin "installing $pkg..." apt_get install -y "$pkg" \
        && log_ok "$label — $desc" \
        || log_error "$pkg" "apt install failed"
    fi
  done
  return 0   # only the sudo failure above stops --setup, not one failed package
}

install_bat() {
  local latest
  run_spin_capture "checking latest version..." latest github_latest "sharkdp/bat"
  if [[ -z "$latest" ]]; then
    if command_exists bat; then
      log_skip "bat $(bat --version | awk '{print $2}') (could not check latest)"; return
    else
      log_error "bat" "could not resolve latest version — network down? re-run once it is back"; return
    fi
  fi
  if command_exists bat; then
    local v; v=$(bat --version | awk '{print $2}')
    if version_lt "$v" "$latest"; then
      log_warn "bat $v → upgrading to $latest"
    else
      log_skip "bat $v"; return
    fi
  fi
  local deb="/tmp/bat_${latest}_${ARCH_DEB}.deb"
  run_spin "downloading bat $latest..." \
    curl -fsSL "https://github.com/sharkdp/bat/releases/download/v${latest}/bat_${latest}_${ARCH_DEB}.deb" -o "$deb" \
    && log_ok "downloaded bat $latest" || { log_error "bat" "download failed"; return; }
  run_spin "installing bat $latest..." \
    bash -c "sudo dpkg -i '$deb' && rm '$deb'" \
    && log_ok "bat $latest installed" \
    || log_error "bat" "install failed"
}

install_delta() {
  local latest
  run_spin_capture "checking latest version..." latest github_latest "dandavison/delta"
  if [[ -z "$latest" ]]; then
    if command_exists delta; then
      log_skip "delta $(delta --version | awk '{print $2}') (could not check latest)"; return
    else
      log_error "delta" "could not resolve latest version — network down? re-run once it is back"; return
    fi
  fi
  if command_exists delta; then
    local v; v=$(delta --version | awk '{print $2}')
    if version_lt "$v" "$latest"; then
      log_warn "delta $v → upgrading to $latest"
    else
      log_skip "delta $v"; return
    fi
  fi
  local deb="/tmp/git-delta_${latest}_${ARCH_DEB}.deb"
  run_spin "downloading delta $latest..." \
    curl -fsSL "https://github.com/dandavison/delta/releases/download/${latest}/git-delta_${latest}_${ARCH_DEB}.deb" -o "$deb" \
    && log_ok "downloaded delta $latest" || { log_error "delta" "download failed"; return; }
  run_spin "installing delta $latest..." \
    bash -c "sudo dpkg -i '$deb' && rm '$deb'" \
    && log_ok "delta $latest installed" \
    || log_error "delta" "install failed"
}

install_fzf() {
  local latest
  run_spin_capture "checking latest version..." latest github_latest "junegunn/fzf"
  if [[ -z "$latest" ]]; then
    if command_exists fzf; then
      log_skip "fzf $(fzf --version | awk '{print $1}') (could not check latest)"; return
    else
      log_error "fzf" "could not resolve latest version — network down? re-run once it is back"; return
    fi
  fi
  local current_path; current_path=$(command -v fzf || true)
  if [[ "$current_path" == "/usr/local/bin/fzf" ]]; then
    local v; v=$(fzf --version | awk '{print $1}')
    if version_lt "$v" "$latest"; then
      log_warn "fzf $v → upgrading to $latest"
    else
      log_skip "fzf $v"; return
    fi
  elif [[ -n "$current_path" ]]; then
    local v; v=$(fzf --version | awk '{print $1}')
    log_warn "fzf $v at $current_path — installing $latest into /usr/local/bin (will take precedence)"
  fi
  local tar="/tmp/fzf_${latest}.tar.gz"
  run_spin "downloading fzf $latest..." \
    curl -fsSL "https://github.com/junegunn/fzf/releases/download/v${latest}/fzf-${latest}-linux_${ARCH_FZF}.tar.gz" -o "$tar" \
    && log_ok "downloaded fzf $latest" || { log_error "fzf" "download failed"; return; }
  run_spin "installing fzf $latest..." \
    bash -c "tar -xf '$tar' -C /tmp fzf && sudo mv /tmp/fzf /usr/local/bin/fzf && rm '$tar'" \
    && log_ok "fzf $latest installed" \
    || log_error "fzf" "install failed"
}

# eza isn't in Ubuntu's apt repos until 23.10+ — apt install fails outright on
# 22.04 ("Unable to locate package"), so install it from its GitHub release
# like fzf/lazygit above instead.
install_eza() {
  local latest
  run_spin_capture "checking latest version..." latest github_latest "eza-community/eza"
  if [[ -z "$latest" ]]; then
    if command_exists eza; then
      log_skip "eza $(eza --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+') (could not check latest)"; return
    else
      log_error "eza" "could not resolve latest version — network down? re-run once it is back"; return
    fi
  fi
  if command_exists eza; then
    local v; v=$(eza --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+')
    if version_lt "$v" "$latest"; then
      log_warn "eza $v → upgrading to $latest"
    else
      log_skip "eza $v"; return
    fi
  fi
  local tar="/tmp/eza_${latest}.tar.gz"
  run_spin "downloading eza $latest..." \
    curl -fsSL "https://github.com/eza-community/eza/releases/download/v${latest}/eza_${ARCH_EZA}.tar.gz" -o "$tar" \
    && log_ok "downloaded eza $latest" || { log_error "eza" "download failed"; return; }
  # Unlike fzf/lazygit's flat archives, eza's tarball stores the binary as
  # "./eza" — extract the whole (single-file) archive rather than naming a
  # member, since GNU tar won't match a bare "eza" pattern against "./eza".
  run_spin "installing eza $latest..." \
    bash -c "tar -xf '$tar' -C /tmp && sudo mv /tmp/eza /usr/local/bin/eza && rm '$tar'" \
    && log_ok "eza $latest installed" \
    || log_error "eza" "install failed"
}

# ripgrep, fd, zoxide, cmake, btop, ninja and jq below are GitHub-release
# installs rather than apt packages — same reasoning as eza: Ubuntu's apt
# versions of these run one to several major versions behind upstream, and
# installing to /usr/local/bin (which precedes /usr/bin on PATH by default)
# means they take over cleanly even if an older apt copy is still present.

install_ripgrep() {
  local latest
  run_spin_capture "checking latest version..." latest github_latest "BurntSushi/ripgrep"
  if [[ -z "$latest" ]]; then
    if command_exists rg; then
      log_skip "ripgrep $(rg --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+') (could not check latest)"; return
    else
      log_error "ripgrep" "could not resolve latest version — network down? re-run once it is back"; return
    fi
  fi
  if command_exists rg; then
    local v; v=$(rg --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+')
    if version_lt "$v" "$latest"; then
      log_warn "ripgrep $v → upgrading to $latest"
    else
      log_skip "ripgrep $v"; return
    fi
  fi
  # Release tag has no "v" prefix (unlike bat/delta/fzf), and the tarball
  # extracts into a versioned subdirectory rather than a flat binary.
  local dir="ripgrep-${latest}-${ARCH_GENERIC}-unknown-linux-musl"
  local tar="/tmp/${dir}.tar.gz"
  run_spin "downloading ripgrep $latest..." \
    curl -fsSL "https://github.com/BurntSushi/ripgrep/releases/download/${latest}/${dir}.tar.gz" -o "$tar" \
    && log_ok "downloaded ripgrep $latest" || { log_error "ripgrep" "download failed"; return; }
  run_spin "installing ripgrep $latest..." \
    bash -c "tar -xf '$tar' -C /tmp && sudo mv /tmp/${dir}/rg /usr/local/bin/rg && rm -rf '$tar' /tmp/${dir}" \
    && log_ok "ripgrep $latest installed" \
    || log_error "ripgrep" "install failed"
}

install_fd() {
  local latest
  run_spin_capture "checking latest version..." latest github_latest "sharkdp/fd"
  if [[ -z "$latest" ]]; then
    if command_exists fd; then
      log_skip "fd $(fd --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+') (could not check latest)"; return
    else
      log_error "fd" "could not resolve latest version — network down? re-run once it is back"; return
    fi
  fi
  if command_exists fd; then
    local v; v=$(fd --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+')
    if version_lt "$v" "$latest"; then
      log_warn "fd $v → upgrading to $latest"
    else
      log_skip "fd $v"; return
    fi
  fi
  # The release binary is named `fd` directly (unlike apt's fd-find, which
  # ships it as `fdfind` and needs a symlink) — extracts into a subdirectory.
  local dir="fd-v${latest}-${ARCH_GENERIC}-unknown-linux-gnu"
  local tar="/tmp/${dir}.tar.gz"
  run_spin "downloading fd $latest..." \
    curl -fsSL "https://github.com/sharkdp/fd/releases/download/v${latest}/${dir}.tar.gz" -o "$tar" \
    && log_ok "downloaded fd $latest" || { log_error "fd" "download failed"; return; }
  run_spin "installing fd $latest..." \
    bash -c "tar -xf '$tar' -C /tmp && sudo mv /tmp/${dir}/fd /usr/local/bin/fd && rm -rf '$tar' /tmp/${dir}" \
    && log_ok "fd $latest installed" \
    || log_error "fd" "install failed"
}

install_zoxide() {
  local latest
  run_spin_capture "checking latest version..." latest github_latest "ajeetdsouza/zoxide"
  if [[ -z "$latest" ]]; then
    if command_exists zoxide; then
      log_skip "zoxide $(zoxide --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+') (could not check latest)"; return
    else
      log_error "zoxide" "could not resolve latest version — network down? re-run once it is back"; return
    fi
  fi
  if command_exists zoxide; then
    local v; v=$(zoxide --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+')
    if version_lt "$v" "$latest"; then
      log_warn "zoxide $v → upgrading to $latest"
    else
      log_skip "zoxide $v"; return
    fi
  fi
  local tar="/tmp/zoxide_${latest}.tar.gz"
  run_spin "downloading zoxide $latest..." \
    curl -fsSL "https://github.com/ajeetdsouza/zoxide/releases/download/v${latest}/zoxide-${latest}-${ARCH_GENERIC}-unknown-linux-musl.tar.gz" -o "$tar" \
    && log_ok "downloaded zoxide $latest" || { log_error "zoxide" "download failed"; return; }
  run_spin "installing zoxide $latest..." \
    bash -c "tar -xf '$tar' -C /tmp zoxide && sudo mv /tmp/zoxide /usr/local/bin/zoxide && rm '$tar'" \
    && log_ok "zoxide $latest installed" \
    || log_error "zoxide" "install failed"
}

# direnv publishes a bare binary per architecture, named after Go's GOARCH
# (amd64/arm64), the same spelling as ARCH_DEB.
install_direnv() {
  local latest
  run_spin_capture "checking latest version..." latest github_latest "direnv/direnv"
  if [[ -z "$latest" ]]; then
    if command_exists direnv; then
      log_skip "direnv $(direnv version 2>/dev/null) (could not check latest)"; return
    else
      log_error "direnv" "could not resolve latest version — network down? re-run once it is back"; return
    fi
  fi
  if command_exists direnv; then
    local v; v=$(direnv version 2>/dev/null)
    if version_lt "$v" "$latest"; then
      log_warn "direnv $v → upgrading to $latest"
    else
      log_skip "direnv $v"; return
    fi
  fi
  local bin="/tmp/direnv_${latest}"
  run_spin "downloading direnv $latest..." \
    curl -fsSL "https://github.com/direnv/direnv/releases/download/v${latest}/direnv.linux-${ARCH_DEB}" -o "$bin" \
    && log_ok "downloaded direnv $latest" || { log_error "direnv" "download failed"; return; }
  run_spin "installing direnv $latest..." \
    bash -c "chmod +x '$bin' && sudo mv '$bin' /usr/local/bin/direnv" \
    && log_ok "direnv $latest installed" \
    || log_error "direnv" "install failed"
}

# dust ships a tarball with one top-level directory that carries the version in
# its name, so the binary is pulled out by wildcard. The musl build is static, so
# it runs on any glibc.
install_dust() {
  local latest
  run_spin_capture "checking latest version..." latest github_latest "bootandy/dust"
  if [[ -z "$latest" ]]; then
    if command_exists dust; then
      log_skip "dust $(dust --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+') (could not check latest)"; return
    else
      log_error "dust" "could not resolve latest version — network down? re-run once it is back"; return
    fi
  fi
  if command_exists dust; then
    local v; v=$(dust --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+')
    if version_lt "$v" "$latest"; then
      log_warn "dust $v → upgrading to $latest"
    else
      log_skip "dust $v"; return
    fi
  fi
  local tar="/tmp/dust_${latest}.tar.gz"
  run_spin "downloading dust $latest..." \
    curl -fsSL "https://github.com/bootandy/dust/releases/download/v${latest}/dust-v${latest}-${ARCH_GENERIC}-unknown-linux-musl.tar.gz" -o "$tar" \
    && log_ok "downloaded dust $latest" || { log_error "dust" "download failed"; return; }
  run_spin "installing dust $latest..." \
    bash -c "tar -xf '$tar' -C /tmp --wildcards '*/dust' --strip-components=1 && sudo mv /tmp/dust /usr/local/bin/dust && rm '$tar'" \
    && log_ok "dust $latest installed" \
    || log_error "dust" "install failed"
}

# difftastic (difft) diffs by syntax tree rather than by line, so a moved
# argument or a re-wrapped expression shows as what changed. delta stays the
# pager; difftastic is `git dft` (.gitconfig) and a second diff view in lazygit
# (| switches). The static musl build where there is one (x86_64), else glibc.
install_difftastic() {
  local latest
  run_spin_capture "checking latest version..." latest github_latest "Wilfred/difftastic"
  if [[ -z "$latest" ]]; then
    if command_exists difft; then
      log_skip "difftastic $(difft --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+') (could not check latest)"; return
    else
      log_error "difftastic" "could not resolve latest version — network down? re-run once it is back"; return
    fi
  fi
  if command_exists difft; then
    local v; v=$(difft --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+')
    if version_lt "$v" "$latest"; then
      log_warn "difftastic $v → upgrading to $latest"
    else
      log_skip "difftastic $v"; return
    fi
  fi
  local tar="$SCRIPT_TMPDIR/difft-${latest}.tar.gz"
  run_spin "downloading difftastic $latest..." \
    curl -fsSL "https://github.com/Wilfred/difftastic/releases/download/${latest}/difft-${latest}-${ARCH_DIFFT}.tar.gz" -o "$tar" \
    && log_ok "downloaded difftastic $latest" || { log_error "difftastic" "download failed"; return; }
  run_spin "installing difftastic $latest..." \
    bash -c "tar -xzf '$tar' -C '$SCRIPT_TMPDIR' difft && sudo install -m755 '$SCRIPT_TMPDIR/difft' /usr/local/bin/difft" \
    && log_ok "difftastic $latest installed" \
    || log_error "difftastic" "install failed"
}

# just runs a project's recipes from its justfile (build, flash, test, ...);
# .zshrc gives it Tab completion of recipe names.
install_just() {
  local latest
  run_spin_capture "checking latest version..." latest github_latest "casey/just"
  if [[ -z "$latest" ]]; then
    if command_exists just; then
      log_skip "just $(just --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+') (could not check latest)"; return
    else
      log_error "just" "could not resolve latest version — network down? re-run once it is back"; return
    fi
  fi
  if command_exists just; then
    local v; v=$(just --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+')
    if version_lt "$v" "$latest"; then
      log_warn "just $v → upgrading to $latest"
    else
      log_skip "just $v"; return
    fi
  fi
  local tar="$SCRIPT_TMPDIR/just-${latest}.tar.gz"
  run_spin "downloading just $latest..." \
    curl -fsSL "https://github.com/casey/just/releases/download/${latest}/just-${latest}-${ARCH_GENERIC}-unknown-linux-musl.tar.gz" -o "$tar" \
    && log_ok "downloaded just $latest" || { log_error "just" "download failed"; return; }
  run_spin "installing just $latest..." \
    bash -c "tar -xzf '$tar' -C '$SCRIPT_TMPDIR' just && sudo install -m755 '$SCRIPT_TMPDIR/just' /usr/local/bin/just" \
    && log_ok "just $latest installed" \
    || log_error "just" "install failed"
}

# duf's release has a .deb per architecture, installed the way bat's is.
install_duf() {
  local latest
  run_spin_capture "checking latest version..." latest github_latest "muesli/duf"
  if [[ -z "$latest" ]]; then
    if command_exists duf; then
      log_skip "duf $(duf --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+' | head -1) (could not check latest)"; return
    else
      log_error "duf" "could not resolve latest version — network down? re-run once it is back"; return
    fi
  fi
  if command_exists duf; then
    local v; v=$(duf --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+' | head -1)
    if version_lt "$v" "$latest"; then
      log_warn "duf $v → upgrading to $latest"
    else
      log_skip "duf $v"; return
    fi
  fi
  local deb="/tmp/duf_${latest}_${ARCH_DEB}.deb"
  run_spin "downloading duf $latest..." \
    curl -fsSL "https://github.com/muesli/duf/releases/download/v${latest}/duf_${latest}_linux_${ARCH_DEB}.deb" -o "$deb" \
    && log_ok "downloaded duf $latest" || { log_error "duf" "download failed"; return; }
  run_spin "installing duf $latest..." \
    bash -c "sudo dpkg -i '$deb' && rm '$deb'" \
    && log_ok "duf $latest installed" \
    || log_error "duf" "install failed"
}

# yazi's zip holds one versionless top-level directory with two binaries: yazi
# itself and ya, its plugin/flavor manager. Both come out of the static musl
# build, so they run on any glibc.
install_yazi() {
  local latest
  run_spin_capture "checking latest version..." latest github_latest "sxyazi/yazi"
  if [[ -z "$latest" ]]; then
    if command_exists yazi; then
      log_skip "yazi $(yazi --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1) (could not check latest)"; return
    else
      log_error "yazi" "could not resolve latest version — network down? re-run once it is back"; return
    fi
  fi
  if command_exists yazi; then
    local v; v=$(yazi --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)
    if version_lt "$v" "$latest"; then
      log_warn "yazi $v → upgrading to $latest"
    else
      log_skip "yazi $v"; return
    fi
  fi
  local dir="yazi-${ARCH_GENERIC}-unknown-linux-musl"
  local zip="$SCRIPT_TMPDIR/$dir.zip"
  run_spin "downloading yazi $latest..." \
    curl -fsSL "https://github.com/sxyazi/yazi/releases/download/v${latest}/${dir}.zip" -o "$zip" \
    && log_ok "downloaded yazi $latest" || { log_error "yazi" "download failed"; return; }
  run_spin "installing yazi $latest..." \
    bash -c "unzip -o '$zip' -d '$SCRIPT_TMPDIR' '$dir/yazi' '$dir/ya' && sudo install -m755 '$SCRIPT_TMPDIR/$dir/yazi' '$SCRIPT_TMPDIR/$dir/ya' /usr/local/bin/" \
    && log_ok "yazi $latest installed" \
    || log_error "yazi" "install failed"
}

# CMake ships a full tree (bin/ + share/cmake-X.Y/ modules the binary loads
# at runtime), not a standalone binary — installed under /opt and symlinked,
# same pattern as Neovim's release tarball below.
install_cmake() {
  local pin latest have
  pin=$(tool_pin cmake) latest=$pin have=$(tool_installed_version cmake)
  [[ -n "$pin" ]] || run_spin_capture "checking latest version..." latest github_latest "Kitware/CMake"
  if [[ -z "$latest" ]]; then
    [[ -n "$have" ]] && { log_skip "CMake $have (could not check latest)"; return; }
    log_error "CMake" "could not resolve latest version — network down? re-run once it is back"; return
  fi
  needs_install "CMake" "$have" "$latest" "$pin" || return
  local dir="cmake-${latest}-linux-${ARCH_GENERIC}"
  local tgz="/tmp/${dir}.tar.gz"
  local url="https://github.com/Kitware/CMake/releases/download/v${latest}/${dir}.tar.gz"
  run_spin_download "downloading CMake $latest" "$url" "$tgz" \
    && log_ok "downloaded CMake $latest ($(human_bytes "$(stat -c %s "$tgz" 2>/dev/null || echo 0)"))" \
    || { log_error "CMake" "download failed"; return; }
  # Remove any previously installed version, not just this exact one — the
  # directory name bakes in the version, so past upgrades would otherwise
  # accumulate as orphaned ~50-100MB trees under /opt forever.
  # /opt/cmake is a stable, version-agnostic alias for the versioned tree, and
  # the /usr/local/bin entry points go through it rather than at the versioned
  # path directly. That way an upgrade only has to repoint this one symlink —
  # the entry points never need touching and can never be left dangling at a
  # tree that a later run deleted.
  run_spin "installing CMake $latest..." \
    bash -c "sudo rm -rf /opt/cmake-*-linux-* && sudo tar -C /opt -xf '$tgz' \
      && sudo ln -sfn /opt/${dir} /opt/cmake \
      && sudo ln -sf /opt/cmake/bin/cmake /usr/local/bin/cmake \
      && sudo ln -sf /opt/cmake/bin/ctest /usr/local/bin/ctest \
      && sudo ln -sf /opt/cmake/bin/cpack /usr/local/bin/cpack \
      && rm '$tgz'" \
    && log_ok "CMake $latest installed" \
    || log_error "CMake" "install failed"
}

# Points /usr/local/bin/arm-none-eabi-* at whatever /opt/arm-gcc currently is.
# Runs on the skip paths too, not just after an install: a toolchain extracted
# before the entry points existed (back when .zshrc prepended /opt/arm-gcc/bin)
# is "up to date" forever and would otherwise never get linked, leaving the
# cross-compiler installed but off PATH. The dangling sweep covers a release
# that drops a tool the previous one shipped. ln -sf makes this idempotent.
arm_gcc_link_tools() {
  sudo bash -c '
    for l in /usr/local/bin/arm-none-eabi-*; do
      [[ -L "$l" && ! -e "$l" ]] && rm -f "$l"
    done
    for b in /opt/arm-gcc/bin/arm-none-eabi-*; do
      [[ -e "$b" ]] && ln -sf "/opt/arm-gcc/bin/$(basename "$b")" "/usr/local/bin/$(basename "$b")"
    done
    :'
}

# Arm's official cross-toolchain for bare-metal Arm targets
# (arm-none-eabi-gcc/g++/gdb/objcopy/...). Not packaged for apt at all —
# Ubuntu's gcc-arm-none-eabi is years stale and frequently missing entirely.
# Installed like CMake (versioned dir under /opt) but symlinked to the fixed
# path /opt/arm-gcc, since that's what Neovim's clangd --query-driver flag
# already hardcodes (lsp-config.lua).
install_arm_gcc() {
  local pin latest have
  pin=$(tool_pin arm-gcc) latest=$pin have=$(tool_installed_version arm-gcc)
  [[ -n "$pin" ]] || run_spin_capture "checking latest version..." latest arm_gcc_latest
  latest=${latest,,}
  # The skip paths relink too: see arm_gcc_link_tools.
  if [[ -z "$latest" ]]; then
    if [[ -n "$have" ]]; then
      [[ -x /opt/arm-gcc/bin/arm-none-eabi-gcc ]] && arm_gcc_link_tools
      log_skip "ARM GNU Toolchain $have (could not check latest)"; return
    fi
    log_error "ARM GNU Toolchain" "could not resolve latest version — network down? re-run once it is back"; return
  fi
  if ! needs_install "ARM GNU Toolchain" "$have" "$latest" "$pin"; then
    [[ -x /opt/arm-gcc/bin/arm-none-eabi-gcc ]] && arm_gcc_link_tools
    return
  fi
  local name="arm-gnu-toolchain-${latest}-${ARCH_GENERIC}-arm-none-eabi"
  local txz="/tmp/${name}.tar.xz"
  # Size comes from the response rather than a hardcoded "~150MB" that was
  # already stale — the 15.3 tarball is roughly twice that.
  local url="https://gitlab.arm.com/api/v4/projects/tooling%2Fgnu-toolchains-for-arm/packages/generic/gnu-toolchain/${latest}/${name}.tar.xz"
  run_spin_download "downloading ARM GNU Toolchain $latest" "$url" "$txz" \
    && log_ok "downloaded ARM GNU Toolchain $latest ($(human_bytes "$(stat -c %s "$txz" 2>/dev/null || echo 0)"))" \
    || { log_error "ARM GNU Toolchain" "download failed"; return; }
  # Same accumulation risk as CMake — the directory name bakes in the
  # version, so clear any prior install before extracting the new one.
  #
  # Every arm-none-eabi-* entry point is symlinked into /usr/local/bin rather
  # than relying on a PATH prepend in .zshrc. .zshrc only runs for interactive
  # shells, so a PATH entry is invisible to cron, systemd, CI, `bash -c`, and
  # to GUI-launched editors (VS Code started from the desktop launcher) —
  # all of which then can't find the cross-compiler that is plainly installed.
  # It also made this very function re-download the toolchain every run once
  # apt's copy was gone. All 35 binaries are arm-none-eabi-prefixed, so there
  # is nothing in /usr/local/bin they can collide with. Symlinks go through
  # the stable /opt/arm-gcc alias, so upgrades don't need to touch them.
  run_spin "installing ARM GNU Toolchain $latest..." \
    bash -c "sudo rm -rf /opt/arm-gnu-toolchain-*-arm-none-eabi && sudo tar -C /opt -xJf '$txz' \
      && sudo ln -sfn /opt/${name} /opt/arm-gcc \
      && rm '$txz'" \
    && arm_gcc_link_tools \
    && log_ok "ARM GNU Toolchain $latest installed ($(ls /opt/arm-gcc/bin/arm-none-eabi-* 2>/dev/null | wc -l) tools linked)" \
    || log_error "ARM GNU Toolchain" "install failed"
}

# ── LLVM version pinning ───────────────────────────────────────────────────────
# By default the LLVM step tracks the newest upstream release. Work sometimes
# requires an exact older version instead (e.g. a project that only builds with
# 18.1.8), so the choice is recorded in a per-machine file and honoured by every
# later run. Untracked and outside the repo on purpose — same reasoning as the
# theme state file: one shared dotfiles checkout, different pins per machine, so
# a work pin never follows the repo to a personal box.
LLVM_PIN_FILE="$HOME/.config/llvm/version"

# Empty output means "track latest", which is the default for an unpinned box.
# The per-machine file wins over the versions file; "latest" in it overrides a
# pin there.
llvm_pin() {
  local v
  if [[ -f "$LLVM_PIN_FILE" ]]; then
    read -r v < "$LLVM_PIN_FILE" 2>/dev/null
  else
    v=$(tool_pin llvm)
  fi
  [[ "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && printf '%s' "$v"
}

# Where the active pin comes from, for the status lines.
llvm_pin_source() {
  # shellcheck disable=SC2088  # a label for the log, not a path to expand
  [[ -f "$LLVM_PIN_FILE" ]] && { printf '%s' "~/${LLVM_PIN_FILE#"$HOME"/}"; return; }
  printf 'dotfiles versions file'
}

# LLVM's 18.x and older Linux builds were made on Ubuntu 18.04 and link
# libtinfo.so.5, which Ubuntu stopped shipping in 24.04. Without it clang,
# clangd and libclang all fail to load. Ubuntu 22.04's libtinfo5 depends only
# on libc6, so that one .deb brings it back; the newest one in the pool is
# picked, since older builds drop out of it.
llvm_ensure_tinfo5() {
  ldd /opt/llvm/bin/clang 2>/dev/null | grep -q 'libtinfo.so.5 => not found' || return 0
  local pool=https://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses
  [[ "$ARCH_DEB" == arm64 ]] && pool=https://ports.ubuntu.com/ubuntu-ports/pool/universe/n/ncurses
  local deb_name deb="$SCRIPT_TMPDIR/libtinfo5.deb"
  deb_name=$(curl -fsSL "$pool/" 2>/dev/null | grep -oP "libtinfo5_6\.3-[^\"]+_${ARCH_DEB}\.deb" | sort -uV | tail -1)
  [[ -n "$deb_name" ]] || { log_error "libtinfo5" "not found in $pool — clang from /opt/llvm will not start"; return; }
  run_spin "installing $deb_name (LLVM 18 and older need it)..." \
    bash -c "curl -fsSL '$pool/$deb_name' -o '$deb' && sudo dpkg -i '$deb' && rm -f '$deb'" \
    && log_ok "libtinfo5 installed for LLVM" \
    || log_error "libtinfo5" "install failed — clang from /opt/llvm will not start"
}

# The clang/clang++ compiler can come from apt instead of /opt/llvm: C23 code
# (constexpr objects) needs clang 19 or newer, while the pinned clang-format
# and clangd stay at exactly 18.1.8. With clang=<major> in the
# versions file, apt's clang-<major> is installed with its libclang (for
# bindgen, which then matches the compiler) and /usr/local/bin/clang and
# clang++ point at it. lld and the other tools still come from /opt/llvm.
#
# Ubuntu's own archive has clang-19 on 24.04 and 26.04 but stops at clang-15 on
# 22.04, so when the release doesn't package that major, LLVM's apt.llvm.org
# repository for the release is added first. Its packages have the same names.
install_clang_compiler() {
  local major; major=$(tool_pin clang)
  [[ -n "$major" ]] || return 0
  apt-cache show "clang-$major" &>/dev/null || add_llvm_apt_repo "$major" || return
  local pkg
  for pkg in "clang-$major" "libclang-$major-dev"; do
    if pkg_installed "$pkg"; then
      log_skip "$pkg"
    else
      run_spin "installing $pkg..." apt_get install -y "$pkg" \
        && log_ok "$pkg installed" \
        || { log_error "$pkg" "apt install failed — is clang $major packaged for this Ubuntu?"; return; }
    fi
  done
  if [[ "$(readlink /usr/local/bin/clang)" == "/usr/bin/clang-$major" \
     && "$(readlink /usr/local/bin/clang++)" == "/usr/bin/clang++-$major" ]]; then
    log_skip "clang → clang-$major"; return
  fi
  sudo ln -sf "/usr/bin/clang-$major" /usr/local/bin/clang \
    && sudo ln -sf "/usr/bin/clang++-$major" /usr/local/bin/clang++ \
    && log_ok "clang and clang++ → clang-$major (clang-format and clangd stay on /opt/llvm)" \
    || log_error "clang" "could not link clang-$major into /usr/local/bin"
}

add_llvm_apt_repo() {
  local major=$1 codename; codename=$(. /etc/os-release && echo "$VERSION_CODENAME")
  local key=/etc/apt/keyrings/apt.llvm.org.gpg
  local list=/etc/apt/sources.list.d/llvm-toolchain-$codename-$major.list
  run_spin "adding apt.llvm.org for clang $major on $codename..." bash -c "
    sudo install -d -m 755 /etc/apt/keyrings &&
    curl -fsSL https://apt.llvm.org/llvm-snapshot.gpg.key | gpg --dearmor | sudo tee '$key' >/dev/null &&
    echo 'deb [arch=${ARCH_DEB} signed-by=$key] https://apt.llvm.org/$codename/ llvm-toolchain-$codename-$major main' | sudo tee '$list' >/dev/null &&
    sudo env DEBIAN_FRONTEND=noninteractive apt-get update -qq" \
    && apt-cache show "clang-$major" &>/dev/null \
    && log_ok "apt.llvm.org added (Ubuntu $codename doesn't package clang-$major)" \
    || { log_error "clang-$major" "not in Ubuntu $codename's archive, and adding apt.llvm.org failed"; return 1; }
}

# clang (and clangd) take C++ headers from the newest GCC under /usr/lib/gcc,
# whether or not that GCC's libstdc++ headers are installed. Installing gcc-14
# alone, as apt install gcc-14 does, made every C++ file fail with "'vector'
# file not found". So install libstdc++-<N>-dev for each GCC a clang selects.
ensure_clang_libstdcxx() {
  local cc gcc_major majors=()
  for cc in /usr/local/bin/clang /opt/llvm/bin/clang; do
    [[ -x "$cc" ]] || continue
    gcc_major=$("$cc" -v -x c++ -fsyntax-only /dev/null 2>&1 \
      | sed -n 's|^Selected GCC installation: .*/\([0-9][0-9]*\)$|\1|p')
    [[ -n "$gcc_major" && " ${majors[*]} " != *" $gcc_major "* ]] && majors+=("$gcc_major")
  done
  for gcc_major in "${majors[@]}"; do
    if pkg_installed "libstdc++-$gcc_major-dev"; then
      log_skip "libstdc++-$gcc_major-dev (C++ headers clang uses)"
    else
      run_spin "installing libstdc++-$gcc_major-dev..." apt_get install -y "libstdc++-$gcc_major-dev" \
        && log_ok "libstdc++-$gcc_major-dev installed (clang uses GCC $gcc_major's C++ headers)" \
        || log_error "libstdc++-$gcc_major-dev" "apt install failed — clang++ cannot find <vector>"
    fi
  done
}

# Turns what the user typed into an exact x.y.z. "latest" asks GitHub; a bare
# major ("18") or major.minor ("18.1") resolves to the newest patch in that
# series, so you don't have to know that 18.1.8 was the last 18.x release.
#
# git ls-remote rather than the GitHub API: the refspec filter keeps it to a
# handful of tags (~0.5s), it needs no jq, and unlike the API it has no
# unauthenticated rate limit to trip over. -rc/-init tags are excluded by the
# x.y.z anchor — a release candidate is never what a pin means.
llvm_resolve_version() {
  local spec="$1"
  case "$spec" in
    latest) github_latest "llvm/llvm-project" ;;
    *.*.*)  printf '%s' "$spec" ;;
    *)      git ls-remote --tags --refs https://github.com/llvm/llvm-project "llvmorg-${spec}*" 2>/dev/null \
              | grep -oP 'llvmorg-\K\d+\.\d+\.\d+$' | sort -V | tail -1 ;;
  esac
}

# Upstream renamed its Linux release assets partway through LLVM's history, and
# the old and new names coexist across the range a pin can reach:
#
#   >= 20.1.0   LLVM-<v>-Linux-X64.tar.xz          LLVM-<v>-Linux-ARM64.tar.xz
#      19.1.x   LLVM-<v>-Linux-X64.tar.xz          (no ARM64 build published)
#   <= 18.x     clang+llvm-<v>-x86_64-linux-gnu-ubuntu-NN.NN.tar.xz
#                                                  clang+llvm-<v>-aarch64-linux-gnu.tar.xz
#
# So the LLVM-<v>-Linux-<ARCH> URL this script used to build unconditionally
# 404s for anything at or below 18.x. The distro suffix on the old x86_64 name
# also moves between releases (ubuntu-18.04, ubuntu-22.04, …), which is why it
# isn't hardcoded: probe the known-good names with a HEAD request first (cheap,
# unmetered), and only if all of them miss fall back to a single API call that
# lists the release's assets and picks the Linux one by pattern.
#
# Echoes the asset filename. The tarball's top-level directory is always that
# name minus .tar.xz, which is what /opt/llvm ends up pointing at.
llvm_asset() {
  local v="$1" a code
  local -a candidates
  if [[ "$ARCH_LLVM" == ARM64 ]]; then
    candidates=("LLVM-${v}-Linux-ARM64.tar.xz" "clang+llvm-${v}-aarch64-linux-gnu.tar.xz")
  else
    candidates=("LLVM-${v}-Linux-X64.tar.xz" "clang+llvm-${v}-x86_64-linux-gnu-ubuntu-18.04.tar.xz")
  fi
  for a in "${candidates[@]}"; do
    code=$(curl -o /dev/null -sIL --max-time 20 -w '%{http_code}' \
      "https://github.com/llvm/llvm-project/releases/download/llvmorg-${v}/${a}" 2>/dev/null)
    [[ "$code" == 200 ]] && { printf '%s' "$a"; return 0; }
  done
  local pat
  if [[ "$ARCH_LLVM" == ARM64 ]]; then
    pat="(LLVM-${v}-Linux-ARM64|clang\+llvm-${v}-aarch64-linux-gnu[^\"]*)\.tar\.xz"
  else
    pat="(LLVM-${v}-Linux-X64|clang\+llvm-${v}-x86_64-linux-gnu[^\"]*)\.tar\.xz"
  fi
  curl -fsSL --max-time 20 "https://api.github.com/repos/llvm/llvm-project/releases/tags/llvmorg-${v}" 2>/dev/null \
    | grep -oP "\"name\": \"\K${pat}(?=\")" | head -1
}

# The active version, read off the /opt/llvm alias rather than by running a
# binary — it costs nothing and works even for a tree whose clangd can't start.
# The x.y.z anchor is what keeps the old naming scheme parsing correctly:
# clang+llvm-18.1.8-...-ubuntu-18.04 yields 18.1.8, because 18.04 isn't x.y.z.
llvm_installed_version() {
  local d; d=$(readlink /opt/llvm 2>/dev/null)
  local v; v=$(printf '%s' "$d" | grep -oP '\d+\.\d+\.\d+' | head -1)
  if [[ -z "$v" && -x /opt/llvm/bin/clangd ]]; then
    v=$(/opt/llvm/bin/clangd --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)
  fi
  printf '%s' "$v"
}

# Every extracted LLVM tree under /opt, newest-extracted first, covering both
# naming schemes. Directories only, so the /opt/llvm alias itself can never turn
# up as a deletion candidate.
llvm_trees() {
  local d
  for d in /opt/LLVM-*-Linux-* /opt/clang+llvm-*-linux-*; do
    [[ -d "$d" && ! -L "$d" ]] && printf '%s\n' "$d"
  done | xargs -r -d '\n' stat -c '%Y %n' 2>/dev/null | sort -rn | cut -d' ' -f2-
}

# Points the /usr/local/bin entry points at whatever /opt/llvm currently is.
# Shared by the install and the switch paths so a version change can't relink
# one way and not the other.
#
# The dangling sweep has to come first: releases don't ship identical llvm-*
# tool sets, so switching from a newer tree to an older one leaves entry points
# for tools the older tree simply doesn't have. Those are exactly the dangling
# links verify_symlinks reports, and nothing else in the script removes them.
#
# llvm-config is EXCLUDED, and must stay excluded. It is the tool build systems
# shell out to in order to locate LLVM, so putting it on PATH silently redirects
# that discovery at this tree. Rust's clang-sys (the loader behind bindgen) asks
# `llvm-config --libdir` and then loads the libclang it finds there — and this
# tarball's libclang cannot resolve its own resource dir when loaded that way,
# so every bindgen build in the system died with "'limits.h' file not found"
# until the symlink was removed. Anything that genuinely wants this tree's LLVM
# can call /opt/llvm/bin/llvm-config by full path.
#
# lldb is deliberately NOT exposed either, for both naming schemes: upstream's
# binaries link a libpython the distro doesn't ship (libpython3.11 for the
# current releases, libpython3.8 for the ubuntu-18.04-era ones, against Ubuntu
# 24.04's 3.12 — an ABI break in both directions), so the bundled lldb cannot
# start. lldb comes from apt instead.
# clang and clang++ are left alone while the versions file pins a separate
# compiler (see install_clang_compiler).
llvm_link_tools() {
  local tools="clangd clang-format clang-tidy lld ld.lld"
  [[ -n "$(tool_pin clang)" ]] || tools+=" clang clang++"
  sudo bash -c '
    for l in /usr/local/bin/*; do
      [[ -L "$l" ]] || continue
      t=$(readlink "$l")
      [[ "$t" == /opt/llvm/* && ! -e "$l" ]] && rm -f "$l"
    done
    for t in '"$tools"'; do
      [[ -e "/opt/llvm/bin/$t" ]] && ln -sf "/opt/llvm/bin/$t" "/usr/local/bin/$t"
    done
    for b in /opt/llvm/bin/llvm-*; do
      n=$(basename "$b")
      [[ "$n" == llvm-config ]] && continue
      ln -sf "/opt/llvm/bin/$n" "/usr/local/bin/$n"
    done
    :'
}

# Keeps the active tree plus the most recently extracted other one, and removes
# the rest. Two trees is what makes switching between the version work needs and
# the newest one a symlink repoint instead of a fresh ~1 GiB download, and the
# cap is what stops every past upgrade accumulating as an orphaned ~12 GB tree
# under /opt forever. MRU by directory mtime rather than a state file: mtime is
# set at extract time, and alternating between two versions never re-extracts,
# so the pair you actually switch between is the pair that survives.
# One "active|ondisk <version> <state> <size> <path>" row per tree under /opt,
# for --llvm's status listing. Separate from llvm_trees because measuring is the
# slow part and only the status report wants it.
llvm_status_rows() {
  local active="$1" d v
  while IFS= read -r d; do
    [[ -n "$d" ]] || continue
    v=$(printf '%s' "$d" | grep -oP '\d+\.\d+\.\d+' | head -1)
    if [[ "$v" == "$active" ]]; then
      printf 'active %-9s active   %-5s %s\n' "$v" "$(du -sh "$d" 2>/dev/null | cut -f1)" "$d"
    else
      printf 'ondisk %-9s on disk  %-5s %s\n' "$v" "$(du -sh "$d" 2>/dev/null | cut -f1)" "$d"
    fi
  done < <(llvm_trees)
}

# Pass 1 to drop every inactive tree instead (what --llvm clean does).
# Echoes the bytes reclaimed.
llvm_prune() {
  local purge_all="${1:-0}" active kept=0 freed=0 d sz
  active=$(readlink -f /opt/llvm 2>/dev/null)
  # Refuse to delete anything if the alias doesn't resolve to a versioned tree.
  # Without this an unset or hand-broken /opt/llvm would make every tree look
  # inactive, and --llvm clean would take the whole toolchain with it.
  [[ -d "$active" && "$active" != /opt/llvm ]] || { printf '0'; return 1; }
  while IFS= read -r d; do
    [[ -n "$d" ]] || continue
    [[ "$d" == "$active" ]] && continue
    if (( purge_all == 0 && kept == 0 )); then kept=1; continue; fi
    sz=$(du -sb "$d" 2>/dev/null | cut -f1)
    sudo rm -rf "$d" && freed=$(( freed + ${sz:-0} ))
  done < <(llvm_trees)
  printf '%s' "$freed"
}

# Ubuntu's clang-format/clang-tidy/clangd are 1-2 major LLVM versions behind
# and don't necessarily track the same version as each other. The official
# release is a single ~1-1.8 GiB combined LLVM/Clang tree (clang, lld, every
# LLVM library, docs, static archives — 7-12GB uncompressed); only the tools
# actually used here are symlinked out, the rest stays private under /opt
# rather than polluting the global PATH with the whole LLVM toolset.
install_llvm_clang_tools() {

  # A pin is an exact request, so it needs no network to decide anything —
  # skipping the latest lookup entirely also means a pinned box can't be told
  # it's out of date by a version it has deliberately declined.
  local pin want
  pin=$(llvm_pin)
  if [[ -n "$pin" ]]; then
    want="$pin"
  else
    run_spin_capture "checking latest version..." want github_latest "llvm/llvm-project"
  fi

  # Resolve the installed tree by its own known path first, same reasoning as
  # install_arm_gcc: relying on PATH means anything that hides or removes the
  # symlink turns the version check into "nothing installed", and this step
  # then re-downloads ~1 GiB. /usr/local/bin is on PATH in practice, so this
  # is defence in depth rather than a live bug — but it guards the single
  # largest download in the script.
  local installed; installed=$(llvm_installed_version)

  if [[ -z "$want" ]]; then
    if [[ -n "$installed" ]]; then
      log_skip "LLVM/Clang tools $installed (could not check latest)"; return
    else
      log_error "LLVM/Clang tools" "could not resolve latest version — network down? re-run once it is back"; return
    fi
  fi

  # Exact equality, not version_lt: a pin has to be able to move backwards, and
  # "installed is newer than what was asked for" is a reason to switch rather
  # than a reason to skip. version_lt is still what phrases the unpinned case,
  # where the only legitimate move is forwards.
  if [[ "$installed" == "$want" ]]; then
    log_skip "LLVM/Clang tools $installed${pin:+ (pinned)}"
    llvm_ensure_tinfo5
    return
  fi
  if [[ -n "$installed" ]]; then
    if [[ -n "$pin" ]]; then
      log_warn "LLVM/Clang tools $installed → switching to pinned $want"
    elif version_lt "$installed" "$want"; then
      log_warn "LLVM/Clang tools $installed → upgrading to $want"
    else
      log_warn "LLVM/Clang tools $installed → moving to $want"
    fi
  fi

  llvm_activate "$want"
}

# Makes $1 the active version, downloading it only if it isn't already extracted
# under /opt. Split out of install_llvm_clang_tools so --llvm shares the exact
# same path — a switch performed by hand and a switch performed by --setup must
# not be able to leave the system in two different states.
llvm_activate() {
  local want="$1" was; was=$(llvm_installed_version)

  # The whole point of keeping a second tree around: once both versions are on
  # disk, moving between them is one symlink repoint and a relink rather than a
  # ~1 GiB download and a multi-minute extract.
  local name dir
  while IFS= read -r dir; do
    [[ -n "$dir" ]] || continue
    if [[ "$dir" == *"-${want}-"* && -x "$dir/bin/clangd" ]]; then name=$(basename "$dir"); break; fi
  done < <(llvm_trees)
  if [[ -n "$name" ]]; then
    run_spin "switching to LLVM/Clang tools $want..." \
      bash -c "sudo ln -sfn '/opt/${name}' /opt/llvm" \
      || { log_error "LLVM/Clang tools" "could not switch to $want"; return; }
    llvm_link_tools || { log_error "LLVM/Clang tools" "switched to $want but relinking /usr/local/bin failed"; return; }
    log_ok "LLVM/Clang tools $want active (already on disk, no download)"
    llvm_ensure_tinfo5
    llvm_report_prune
    return
  fi

  local asset
  run_spin_capture "resolving LLVM/Clang tools $want release asset..." asset llvm_asset "$want"
  if [[ -z "$asset" ]]; then
    log_error "LLVM/Clang tools" "no Linux $ARCH_LLVM release asset for $want — check the version exists at github.com/llvm/llvm-project/releases"
    return
  fi
  name="${asset%.tar.xz}"
  local txz="$SCRIPT_TMPDIR/${asset}"
  local url="https://github.com/llvm/llvm-project/releases/download/llvmorg-${want}/${asset}"

  # Cheap pre-flight, because the failure it prevents is expensive: running out
  # of room part-way through leaves a half-extracted tree that looks installed.
  local avail; avail=$(df --output=avail -k /opt 2>/dev/null | tail -1 | tr -d ' ')
  if [[ "$avail" =~ ^[0-9]+$ ]] && (( avail < 15 * 1024 * 1024 )); then
    log_error "LLVM/Clang tools" "only $(human_bytes $(( avail * 1024 ))) free on /opt — an LLVM tree needs 7-12GB plus the tarball"
    return
  fi

  # Progress bar rather than a plain spinner: this is by far the largest thing
  # the script fetches, and the size is reported from the response/file itself
  # rather than hardcoded, so it can't drift as upstream releases grow.
  run_spin_download "downloading LLVM/Clang tools $want" "$url" "$txz" \
    && log_ok "downloaded LLVM/Clang tools $want ($(human_bytes "$(stat -c %s "$txz" 2>/dev/null || echo 0)"))" \
    || { log_error "LLVM/Clang tools" "download failed"; return; }

  # Extract BEFORE removing anything. The old order (rm -rf the previous tree,
  # then untar) destroyed the working toolchain before the replacement landed,
  # so a failed or interrupted extract left the machine with no clang at all.
  # Pruning now happens after /opt/llvm has been repointed at a tree that has
  # been checked, which also means the previous version stays switchable.
  run_spin "installing LLVM/Clang tools $want (extracting, this takes a while)..." \
    bash -c "sudo rm -rf '/opt/${name}' && sudo tar -C /opt -xJf '$txz' && rm -f '$txz'" \
    || { log_error "LLVM/Clang tools" "extract failed"; rm -f "$txz"; return; }

  # An unexpected tarball layout has to fail here, while the previous version is
  # still the active one, rather than after /opt/llvm has been pointed at a tree
  # that can't serve the tools everything else in this script assumes.
  local t missing=""
  for t in clangd clang-format clang-tidy clang clang++; do
    [[ -x "/opt/${name}/bin/$t" ]] || missing+="$t "
  done
  if [[ -n "$missing" ]]; then
    log_error "LLVM/Clang tools" "$want extracted without ${missing% } — /opt/llvm left at ${was:-unset}"
    return
  fi

  # Same stable-alias scheme as CMake: /opt/llvm tracks the versioned tree and
  # every entry point goes through it, so a version change repoints one symlink
  # instead of N — and none of them can survive as dangling links into a tree
  # a later run has already deleted.
  run_spin "activating LLVM/Clang tools $want..." \
    bash -c "sudo ln -sfn '/opt/${name}' /opt/llvm" \
    || { log_error "LLVM/Clang tools" "could not repoint /opt/llvm at $want"; return; }
  llvm_link_tools || { log_error "LLVM/Clang tools" "$want extracted but relinking /usr/local/bin failed"; return; }
  log_ok "LLVM/Clang tools $want installed"
  llvm_ensure_tinfo5
  llvm_report_prune
}

# Prunes behind a spinner and only says anything when it actually removed a tree.
# Behind a spinner because du over a 12GB tree takes a few seconds, and silent
# because "nothing to reclaim" is the normal case and doesn't need a line.
llvm_report_prune() {
  local freed
  run_spin_capture "pruning older LLVM trees..." freed llvm_prune "${1:-0}"
  [[ "$freed" =~ ^[0-9]+$ ]] && (( freed > 0 )) \
    && log_ok "reclaimed $(human_bytes "$freed") from inactive LLVM trees"
}

# btop's tarball ships extras (themes, desktop file, install/uninstall
# scripts) alongside bin/btop — only the binary is needed here; it falls back
# to its built-in default theme without the themes directory.
install_btop() {
  local latest
  run_spin_capture "checking latest version..." latest github_latest "aristocratos/btop"
  if [[ -z "$latest" ]]; then
    if command_exists btop; then
      log_skip "btop $(btop --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+') (could not check latest)"; return
    else
      log_error "btop" "could not resolve latest version — network down? re-run once it is back"; return
    fi
  fi
  if command_exists btop; then
    local v; v=$(btop --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+')
    if version_lt "$v" "$latest"; then
      log_warn "btop $v → upgrading to $latest"
    else
      log_skip "btop $v"; return
    fi
  fi
  local tar="/tmp/btop_${latest}.tar.gz"
  run_spin "downloading btop $latest..." \
    curl -fsSL "https://github.com/aristocratos/btop/releases/download/v${latest}/btop-${ARCH_GENERIC}-unknown-linux-musl.tar.gz" -o "$tar" \
    && log_ok "downloaded btop $latest" || { log_error "btop" "download failed"; return; }
  run_spin "installing btop $latest..." \
    bash -c "tar -xf '$tar' -C /tmp && sudo mv /tmp/btop/bin/btop /usr/local/bin/btop && rm -rf '$tar' /tmp/btop" \
    && log_ok "btop $latest installed" \
    || log_error "btop" "install failed"
}

install_ninja() {
  local pin latest have
  pin=$(tool_pin ninja) latest=$pin have=$(tool_installed_version ninja)
  [[ -n "$pin" ]] || run_spin_capture "checking latest version..." latest github_latest "ninja-build/ninja"
  if [[ -z "$latest" ]]; then
    [[ -n "$have" ]] && { log_skip "ninja $have (could not check latest)"; return; }
    log_error "ninja" "could not resolve latest version — network down? re-run once it is back"; return
  fi
  needs_install "ninja" "$have" "$latest" "$pin" || return
  local zip="/tmp/ninja_${latest}.zip"
  run_spin "downloading ninja $latest..." \
    curl -fsSL "https://github.com/ninja-build/ninja/releases/download/v${latest}/ninja-linux${ARCH_NINJA}.zip" -o "$zip" \
    && log_ok "downloaded ninja $latest" || { log_error "ninja" "download failed"; return; }
  run_spin "installing ninja $latest..." \
    bash -c "unzip -o '$zip' -d /tmp ninja && sudo mv /tmp/ninja /usr/local/bin/ninja && rm '$zip'" \
    && log_ok "ninja $latest installed" \
    || log_error "ninja" "install failed"
}

# The Bitwarden CLI, for .local/bin/git-credential-bw. It lives in the
# monorepo bitwarden/clients next to the web and desktop apps, so GitHub's
# "latest release" is whichever of them shipped last — the CLI is found by its
# cli-vX.Y.Z tags instead (git ls-remote, like llvm_resolve_version). The
# native zip rather than the npm package: no Node needed, no global npm tree.
bw_latest() {
  git ls-remote --tags --refs https://github.com/bitwarden/clients 'cli-v*' 2>/dev/null \
    | grep -oP 'cli-v\K\d+\.\d+\.\d+$' | sort -V | tail -1
}

install_bw() {
  local latest
  run_spin_capture "checking latest version..." latest bw_latest
  if [[ -z "$latest" ]]; then
    if command_exists bw; then
      log_skip "bw $(bw --version 2>/dev/null) (could not check latest)"; return
    else
      log_error "bw" "could not resolve latest version — network down? re-run once it is back"; return
    fi
  fi
  if command_exists bw; then
    local v; v=$(bw --version 2>/dev/null)
    if version_lt "$v" "$latest"; then
      log_warn "bw $v → upgrading to $latest"
    else
      log_skip "bw $v"; return
    fi
  fi
  local asset="bw-linux-${latest}.zip"
  [[ "$ARCH_DEB" == arm64 ]] && asset="bw-linux-arm64-${latest}.zip"
  local zip="$SCRIPT_TMPDIR/$asset"
  run_spin "downloading bw $latest..." \
    curl -fsSL "https://github.com/bitwarden/clients/releases/download/cli-v${latest}/${asset}" -o "$zip" \
    && log_ok "downloaded bw $latest" || { log_error "bw" "download failed"; return; }
  run_spin "installing bw $latest..." \
    bash -c "unzip -o '$zip' -d '$SCRIPT_TMPDIR' bw && sudo install -m755 '$SCRIPT_TMPDIR/bw' /usr/local/bin/bw" \
    && log_ok "bw $latest installed" \
    || log_error "bw" "install failed"
}

# jq's release tag is "jq-X.Y.Z" rather than the "vX.Y.Z" every other tool
# here uses, and ships a raw binary asset with no archive to extract.
install_jq() {
  local latest
  run_spin_capture "checking latest version..." latest github_latest "jqlang/jq"
  if [[ -z "$latest" ]]; then
    if command_exists jq; then
      log_skip "jq $(jq --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+') (could not check latest)"; return
    else
      log_error "jq" "could not resolve latest version — network down? re-run once it is back"; return
    fi
  fi
  if command_exists jq; then
    local v; v=$(jq --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+')
    if version_lt "$v" "$latest"; then
      log_warn "jq $v → upgrading to $latest"
    else
      log_skip "jq $v"; return
    fi
  fi
  local bin="/tmp/jq_${latest}"
  run_spin "downloading jq $latest..." \
    curl -fsSL "https://github.com/jqlang/jq/releases/download/jq-${latest}/jq-linux-${ARCH_DEB}" -o "$bin" \
    && log_ok "downloaded jq $latest" || { log_error "jq" "download failed"; return; }
  run_spin "installing jq $latest..." \
    bash -c "chmod +x '$bin' && sudo mv '$bin' /usr/local/bin/jq" \
    && log_ok "jq $latest installed" \
    || log_error "jq" "install failed"
}

install_fonts() {
  local font_dir="$HOME/.local/share/fonts"
  mkdir -p "$font_dir"
  local installed=0

  if fc-list | grep -q "FiraCode Nerd Font"; then
    log_skip "FiraCode Nerd Font (already available)"
  else
    local fira_zip="/tmp/FiraCode.zip"
    run_spin "downloading FiraCode Nerd Font..." \
      curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip" -o "$fira_zip" \
      && log_ok "downloaded FiraCode Nerd Font" || { log_error "FiraCode Nerd Font" "download failed"; return; }
    local fira_tmp; fira_tmp=$(mktemp -d -p "$SCRIPT_TMPDIR")
    unzip -o "$fira_zip" -d "$fira_tmp" &>/dev/null \
      && find "$fira_tmp" -name "*.ttf" -exec mv {} "$font_dir/" \; \
      && rm -rf "$fira_tmp" "$fira_zip" \
      && (( ++installed )) \
      && log_ok "FiraCode Nerd Font" \
      || { rm -rf "$fira_tmp" "$fira_zip"; log_error "FiraCode Nerd Font" "install failed"; }
  fi

  # Maple Mono NL, for italics only: Fira Code has no italic face, so kitty takes
  # italic and bold italic from this family. NL has no ligatures, so a comment
  # never draws == or <= differently from the Fira Code beside it. The release
  # publishes a sha256 for the archive, checked before anything is unpacked.
  if fc-list | grep -q "Maple Mono NL"; then
    log_skip "Maple Mono NL italics (already available)"
  else
    local maple="https://github.com/subframe7536/maple-font/releases/latest/download"
    local maple_zip="$SCRIPT_TMPDIR/MapleMonoNL-TTF.zip" maple_sum
    if run_spin "downloading Maple Mono NL..." curl -fsSL "$maple/MapleMonoNL-TTF.zip" -o "$maple_zip" \
        && maple_sum=$(curl -fsSL "$maple/MapleMonoNL-TTF.sha256" | grep -oE '^[0-9a-f]{64}') \
        && echo "$maple_sum  $maple_zip" | sha256sum -c --quiet - &>/dev/null \
        && unzip -o -j -q "$maple_zip" MapleMonoNL-Italic.ttf MapleMonoNL-BoldItalic.ttf -d "$font_dir"; then
      (( ++installed ))
      log_ok "Maple Mono NL italics"
    else
      log_error "Maple Mono NL" "download, checksum or unzip failed"
    fi
  fi

  (( installed > 0 )) && fc-cache -f "$font_dir" &>/dev/null
}

# Kitty and Oh My Zsh below install via each project's official
# `curl | sh` script — no checksum/signature check, just the upstream-
# recommended method. Accepted tradeoff: trusting the origin host, same as
# running any other vendor-provided installer.
install_kitty() {
  install_kitty_app
  [[ -x "$HOME/.local/kitty.app/bin/kitty" ]] && kitty_desktop_files
}

# The launcher entries kitty's install docs describe, so Kitty shows up in the
# app grid. Rewritten on every run: the paths in them are this account's, and
# an upgrade replaces the copies inside kitty.app.
kitty_desktop_files() {
  local app="$HOME/.local/kitty.app" dir="$HOME/.local/share/applications" f
  mkdir -p "$dir"
  for f in kitty.desktop kitty-open.desktop; do
    [[ -f "$app/share/applications/$f" ]] || continue
    sed -e "s|Icon=kitty|Icon=$app/share/icons/hicolor/256x256/apps/kitty.png|g" \
        -e "s|Exec=kitty|Exec=$app/bin/kitty|g" \
        "$app/share/applications/$f" > "$dir/$f"
  done
  log_ok "Kitty launcher in the app grid"
}

install_kitty_app() {
  local latest
  run_spin_capture "checking latest version..." latest github_latest "kovidgoyal/kitty"
  if [[ -z "$latest" ]]; then
    if command_exists kitty; then
      log_skip "Kitty $(kitty --version | awk '{print $2}') (could not check latest)"; return
    else
      log_error "Kitty" "could not resolve latest version — network down? re-run once it is back"; return
    fi
  fi
  if command_exists kitty; then
    local v; v=$(kitty --version | awk '{print $2}')
    if version_lt "$v" "$latest"; then
      log_warn "Kitty $v → upgrading to $latest"
    else
      log_skip "Kitty $v"; return
    fi
  fi
  run_spin "installing Kitty $latest..." \
    bash -c "curl -fsSL https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin launch=n" \
    && log_ok "Kitty $latest installed" \
    || log_error "Kitty" "install failed"

  local kitty_bin="$HOME/.local/kitty.app/bin"
  [[ ":$PATH:" != *":$kitty_bin:"* ]] && export PATH="$kitty_bin:$PATH"
}

install_lazygit() {
  local latest
  run_spin_capture "checking latest version..." latest github_latest "jesseduffield/lazygit"
  if [[ -z "$latest" ]]; then
    if command_exists lazygit; then
      log_skip "lazygit $(lazygit --version | grep -oP ', version=\K[^,]+') (could not check latest)"; return
    else
      log_error "lazygit" "could not resolve latest version — network down? re-run once it is back"; return
    fi
  fi
  if command_exists lazygit; then
    local v; v=$(lazygit --version | grep -oP ', version=\K[^,]+')
    if version_lt "$v" "$latest"; then
      log_warn "lazygit $v → upgrading to $latest"
    else
      log_skip "lazygit $v"; return
    fi
  fi
  local tar="/tmp/lazygit_${latest}.tar.gz"
  run_spin "downloading lazygit $latest..." \
    curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/v${latest}/lazygit_${latest}_Linux_${ARCH_LG}.tar.gz" -o "$tar" \
    && log_ok "downloaded lazygit $latest" || { log_error "lazygit" "download failed"; return; }
  run_spin "installing lazygit $latest..." \
    bash -c "tar -xf '$tar' -C /tmp lazygit && sudo mv /tmp/lazygit /usr/local/bin/lazygit && rm '$tar'" \
    && log_ok "lazygit $latest installed" \
    || log_error "lazygit" "install failed"
}

# GitLab CLI. Ubuntu's apt glab trails upstream by dozens of releases; the
# upstream .deb has the same package name, so dpkg upgrades it in place.
install_glab() {
  local latest
  run_spin_capture "checking latest version..." latest glab_latest
  if [[ -z "$latest" ]]; then
    if command_exists glab; then
      log_skip "glab $(glab --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1) (could not check latest)"; return
    else
      log_error "glab" "could not resolve latest version — network down? re-run once it is back"; return
    fi
  fi
  if command_exists glab; then
    local v; v=$(glab --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)
    if version_lt "$v" "$latest"; then
      log_warn "glab $v → upgrading to $latest"
    else
      log_skip "glab $v"; return
    fi
  fi
  local deb="/tmp/glab_${latest}_${ARCH_DEB}.deb"
  run_spin "downloading glab $latest..." \
    curl -fsSL "https://gitlab.com/gitlab-org/cli/-/releases/v${latest}/downloads/glab_${latest}_linux_${ARCH_DEB}.deb" -o "$deb" \
    && log_ok "downloaded glab $latest" || { log_error "glab" "download failed"; return; }
  run_spin "installing glab $latest..." \
    bash -c "sudo dpkg -i '$deb' && rm '$deb'" \
    && log_ok "glab $latest installed" \
    || log_error "glab" "install failed"
}

# GitHub CLI, installed alongside glab so either forge works out of the box;
# each stays inactive until `gh auth login` or `glab auth login`. The release
# .deb has the same package name as Ubuntu's older apt gh, so dpkg upgrades it
# in place. The release publishes sha256 sums, checked before installing.
install_gh() {
  local latest
  run_spin_capture "checking latest version..." latest github_latest "cli/cli"
  if [[ -z "$latest" ]]; then
    if command_exists gh; then
      log_skip "gh $(gh --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+') (could not check latest)"; return
    else
      log_error "gh" "could not resolve latest version — network down? re-run once it is back"; return
    fi
  fi
  if command_exists gh; then
    local v; v=$(gh --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+')
    if version_lt "$v" "$latest"; then
      log_warn "gh $v → upgrading to $latest"
    else
      log_skip "gh $v"; return
    fi
  fi
  local name="gh_${latest}_linux_${ARCH_DEB}.deb" base="https://github.com/cli/cli/releases/download/v${latest}"
  run_spin "downloading gh $latest..." \
    curl -fsSL "$base/$name" -o "$SCRIPT_TMPDIR/$name" \
    && log_ok "downloaded gh $latest" || { log_error "gh" "download failed"; return; }
  local sums
  sums=$(curl -fsSL "$base/gh_${latest}_checksums.txt") \
    && (cd "$SCRIPT_TMPDIR" && grep " $name\$" <<<"$sums" | sha256sum -c --quiet - &>/dev/null) \
    || { log_error "gh" "the download does not match the release's sha256"; return; }
  run_spin "installing gh $latest..." \
    sudo dpkg -i "$SCRIPT_TMPDIR/$name" \
    && log_ok "gh $latest installed" \
    || log_error "gh" "install failed"
}

# Rust via the official rustup installer (stable toolchain: rustc, cargo,
# rustfmt, clippy). Needed in its own right for the Rust work nvim is set up
# for, and by install_tree_sitter_cli on hosts where the prebuilt CLI can't
# run. -y only answers the installer's prompt; the PATH setup is rustup's
# default, which sources ~/.cargo/env from ~/.profile, ~/.bashrc and
# ~/.zshenv — none of them symlinked from this repo, so it never dirties
# .zshrc, and ~/.profile puts cargo on PATH for GUI-launched editors too.
# Everything below calls rustup/rustc by full path, because the shell running
# this script started before ~/.cargo/bin existed.
install_rust() {
  local rustup="$HOME/.cargo/bin/rustup" rustc="$HOME/.cargo/bin/rustc"
  if [[ -x "$rustup" ]]; then
    local v out; v=$("$rustc" --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+')
    # `rustup check` exits non-zero when an update is available, so its exit
    # status can't tell "no network" from "update pending" — read the text.
    run_spin_capture "checking latest version..." out bash -c "'$rustup' check 2>&1; true"
    if grep -q "^stable.*Update available" <<<"$out"; then
      log_warn "Rust $v → updating stable"
      run_spin "updating Rust stable..." "$rustup" update stable \
        && log_ok "Rust $("$rustc" --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+') installed" \
        || log_error "Rust" "update failed"
    else
      log_skip "Rust $v"
    fi
    return
  fi
  run_spin "installing Rust (rustup, stable)..." \
    bash -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y" \
    && log_ok "Rust $("$rustc" --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+') installed" \
    || log_error "Rust" "install failed"
}

# nvim-treesitter's `main` branch compiles parsers locally and needs the
# tree-sitter CLI to do it — 0.26.1 or newer. Deliberately NOT from apt: Ubuntu
# 24.04 ships 0.20.8, six minor versions too old, and installing it would look
# like success while every :TSUpdate failed. Upstream also asks specifically for
# the released binary rather than the npm package.
#
# Every upstream Linux binary from 0.26.1 on links against glibc 2.39, so on
# anything older (Ubuntu 22.04 ships 2.35) the download installs "fine" and
# then can't start — every parser compile fails with "GLIBC_2.39 not found".
# There is no prebuilt that is both new enough and old-glibc compatible, so
# those hosts build the same release from crates.io with the rustup toolchain.
install_tree_sitter_cli() {
  local latest
  run_spin_capture "checking latest version..." latest github_latest "tree-sitter/tree-sitter"
  if [[ -z "$latest" ]]; then
    if command_exists tree-sitter; then
      log_skip "tree-sitter $(tree-sitter --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+') (could not check latest)"; return
    else
      log_error "tree-sitter" "could not resolve latest version — network down? re-run once it is back"; return
    fi
  fi
  if command_exists tree-sitter; then
    local v; v=$(tree-sitter --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+')
    if [[ -z "$v" ]]; then
      log_warn "tree-sitter on PATH won't run → reinstalling $latest"
    elif version_lt "$v" "$latest"; then
      log_warn "tree-sitter $v → upgrading to $latest"
    else
      log_skip "tree-sitter $v"; return
    fi
  fi
  local glibc; glibc=$(getconf GNU_LIBC_VERSION 2>/dev/null | grep -oP '\d+\.\d+')
  if [[ -n "$glibc" ]] && version_lt "$glibc" 2.39; then
    local cargo="$HOME/.cargo/bin/cargo"
    [[ -x "$cargo" ]] || { log_error "tree-sitter" "glibc $glibc can't run the prebuilt binary and cargo is missing (see the Rust step)"; return; }
    run_spin "building tree-sitter $latest from source (glibc $glibc < 2.39, no usable prebuilt)..." \
      bash -c "'$cargo' install tree-sitter-cli --locked --version '$latest' --root '$SCRIPT_TMPDIR/tree-sitter' \
        && sudo install -m755 '$SCRIPT_TMPDIR/tree-sitter/bin/tree-sitter' /usr/local/bin/tree-sitter" \
      && log_ok "tree-sitter $latest built and installed" \
      || log_error "tree-sitter" "build failed"
    return
  fi
  local zip="$SCRIPT_TMPDIR/tree-sitter-${latest}.zip"
  run_spin "downloading tree-sitter $latest..." \
    curl -fsSL "https://github.com/tree-sitter/tree-sitter/releases/download/v${latest}/tree-sitter-cli-linux-${ARCH_TS}.zip" -o "$zip" \
    && log_ok "downloaded tree-sitter $latest" || { log_error "tree-sitter" "download failed"; return; }
  run_spin "installing tree-sitter $latest..." \
    bash -c "unzip -o '$zip' -d '$SCRIPT_TMPDIR' tree-sitter && sudo install -m755 '$SCRIPT_TMPDIR/tree-sitter' /usr/local/bin/tree-sitter" \
    && log_ok "tree-sitter $latest installed" \
    || log_error "tree-sitter" "install failed"
}

# Neovim is pinned to an exact release rather than tracking latest, so that a
# nightly never lands on this machine by surprise: lua/plugins/treesitter.lua
# tracks nvim-treesitter, whose support policy is the *latest stable* and the
# *latest nightly* only.
#
# 0.12 is the floor, not a preference. nvim-treesitter's `main` branch requires
# Neovim 0.12+; its old `master` branch is frozen and caps at 0.11 (its last
# commit, 2026-03-23, is "list support upper bounds"). This config used to sit
# on master/0.11 for exactly that reason — see "Why Neovim is pinned" in the
# README for the migration and what broke.
NVIM_VERSION="0.12.6"

install_neovim() {
  local want="v$NVIM_VERSION"
  if command_exists nvim; then
    local v; v=$(nvim --version | head -1 | sed 's/NVIM //')
    if [[ "$v" == "$want" ]]; then
      log_skip "Neovim $v"; return
    fi
    log_warn "Neovim $v found, pin is $want — replacing"
  fi

  # Earlier revisions of this script installed Neovim from ppa:neovim-ppa/unstable
  # on Ubuntu, which tracks nightly — exactly what the pin above exists to avoid.
  # Remove that package if it is still around: it owns /usr/bin/nvim, and leaving
  # it installed means two Neovims on the box differing only by PATH order.
  if pkg_installed neovim; then
    run_spin "removing nightly Neovim from apt..." apt_get remove -y neovim \
      && log_ok "removed apt Neovim (nightly PPA)" \
      || log_error "Neovim" "could not remove the apt package"
  fi

  local tgz="$SCRIPT_TMPDIR/nvim-linux-${ARCH_NVIM}.tar.gz"
  run_spin "downloading Neovim $want..." \
    curl -fsSL "https://github.com/neovim/neovim/releases/download/${want}/nvim-linux-${ARCH_NVIM}.tar.gz" -o "$tgz" \
    && log_ok "downloaded Neovim $want" || { log_error "Neovim" "download failed"; return; }
  run_spin "installing Neovim..." \
    bash -c "sudo rm -rf /opt/nvim-linux-${ARCH_NVIM} && sudo tar -C /opt -xf '$tgz' && sudo ln -sf /opt/nvim-linux-${ARCH_NVIM}/bin/nvim /usr/local/bin/nvim" \
    && log_ok "Neovim $want" || log_error "Neovim" "install failed"
}

install_omz() {
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    log_skip "Oh My Zsh"; return
  fi
  run_spin "installing Oh My Zsh..." \
    bash -c "RUNZSH=no CHSH=no sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\"" \
    && log_ok "Oh My Zsh" \
    || { log_error "Oh My Zsh" "install failed"; return; }
  # OMZ generates a default ~/.zshrc — remove it so our symlink can be created
  [[ -f "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]] && rm "$HOME/.zshrc" \
    && log_ok "removed OMZ default .zshrc (will be replaced by dotfiles symlink)"
}

# Oh My Zsh's custom theme and plugins: directory under $ZSH_CUSTOM → git URL.
# The versions file pins each by commit, under its directory's name.
declare -A OMZ_REPOS=(
  ["themes/powerlevel10k"]="https://github.com/romkatv/powerlevel10k.git"
  ["plugins/zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions.git"
  ["plugins/fzf-tab"]="https://github.com/Aloxaf/fzf-tab.git"
  ["plugins/fzf-git"]="https://github.com/junegunn/fzf-git.sh.git"
  ["plugins/zsh-bat"]="https://github.com/fdellwing/zsh-bat.git"
  ["plugins/zsh-syntax-highlighting"]="https://github.com/zsh-users/zsh-syntax-highlighting.git"
)

# Each clone is checked out, detached, at the commit the versions file pins it
# to, so every machine runs the same plugin code; "latest" (or no line) moves
# it to upstream's newest commit instead. Before the pins a clone stayed at
# whatever commit it had on the day it was made, and machines drifted apart.
install_omz_plugins() {
  local custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

  local builtins=(fzf git)
  for p in "${builtins[@]}"; do
    log_skip "$p (built-in)"
  done

  local rel name dir pin have want
  for rel in "${!OMZ_REPOS[@]}"; do
    name=$(basename "$rel"); dir="$custom/$rel"
    if [[ ! -d "$dir/.git" ]]; then
      run_spin "cloning $name..." git clone -q --depth=1 "${OMZ_REPOS[$rel]}" "$dir" \
        || { log_error "$name" "clone failed"; continue; }
    fi
    pin=$(tool_pin "$name")
    have=$(git -C "$dir" rev-parse HEAD 2>/dev/null)
    if [[ -n "$pin" && "$have" == "$pin" ]]; then
      log_skip "$name ${pin:0:7} (pinned)"; continue
    fi
    # Only the wanted commit is fetched: the pin, or upstream's HEAD when it
    # tracks latest. A shallow clone stays shallow.
    local depth=()
    [[ $(git -C "$dir" rev-parse --is-shallow-repository 2>/dev/null) == true ]] && depth=(--depth=1)
    run_spin "fetching $name..." git -C "$dir" fetch -q "${depth[@]}" origin "${pin:-HEAD}" \
      || { log_error "$name" "fetch failed — network down? re-run once it is back"; continue; }
    want=$(git -C "$dir" rev-parse FETCH_HEAD)
    if [[ "$have" == "$want" ]]; then
      log_skip "$name ${have:0:7}"; continue
    fi
    git -C "$dir" -c advice.detachedHead=false checkout -q "$want" \
      && log_ok "$name ${have:+${have:0:7} → }${want:0:7}${pin:+ (pinned)}" \
      || log_error "$name" "checkout of ${want:0:7} failed (local changes in $dir?)"
  done
}

# uv replaces pyenv (interpreters) and Poetry (projects, venvs, lockfiles): it
# downloads whatever Python a project asks for. The standalone installer is used
# so `uv self update` works later; UV_NO_MODIFY_PATH keeps it out of the shell rc
# files (~/.zshrc is a symlink into this repo, and ~/.local/bin is already on
# PATH there).
install_uv() {
  local pin latest have
  pin=$(tool_pin uv) latest=$pin have=$(tool_installed_version uv)
  [[ -n "$pin" ]] || run_spin_capture "checking latest version..." latest github_latest "astral-sh/uv"
  if [[ -z "$latest" ]]; then
    [[ -n "$have" ]] && { log_skip "uv $have (could not check latest)"; return; }
    log_error "uv" "could not resolve latest version — network down? re-run once it is back"; return
  fi
  needs_install "uv" "$have" "$latest" "$pin" || return
  if [[ -n "$have" ]]; then
    # self update takes a target version, and moves down to it as well as up
    run_spin "moving uv to $latest..." uv self update "$latest" \
      && log_ok "uv $latest installed" \
      || log_error "uv" "update failed (installed some way other than the standalone installer?)"
    return
  fi
  run_spin "installing uv $latest..." \
    bash -c "curl -LsSf https://astral.sh/uv/$latest/install.sh | UV_NO_MODIFY_PATH=1 sh" \
    && log_ok "uv $latest installed" \
    || log_error "uv" "install failed"
}

# Editor tooling on the global PATH, shared by Neovim and the CLI, so both run
# the same version of each tool.
#
# Python tools come from `uv tool`, so uv is the only Python installer here.
# A tool in the versions file is installed at exactly that version. Otherwise
# `uv tool install --upgrade` moves it to the newest release; unlike `uv tool
# upgrade`, it also drops a ==pin the tool was installed with before. --force
# lets uv take over a shim left by an earlier pipx install, which uv otherwise
# refuses to overwrite.
install_uv_tool() {
  local pkg="$1" label="$2" before after
  command_exists uv || { log_error "$label" "uv is required (installed in the Python step)"; return; }
  before=$(uv_tool_version "$pkg")
  local pin; pin=$(tool_pin "$pkg")
  if [[ -n "$pin" ]]; then
    [[ "$before" == "$pin" ]] && { log_skip "$label $pin (pinned)"; return; }
    run_spin "installing $label $pin..." uv tool install --force "$pkg==$pin" \
      && log_ok "$label ${before:+$before → }$pin (pinned)" \
      || log_error "$label" "install of $pin failed"
    return
  fi
  if [[ -z "$before" ]]; then
    run_spin "installing $label..." uv tool install --force "$pkg" \
      && log_ok "$label $(uv_tool_version "$pkg") installed" \
      || log_error "$label" "install failed"
    return
  fi
  run_spin "checking $label for updates..." uv tool install --force --upgrade "$pkg" \
    || { log_error "$label" "upgrade failed"; return; }
  after=$(uv_tool_version "$pkg")
  if [[ "$before" != "$after" ]]; then
    log_ok "$label $before → $after"
  else
    log_skip "$label $after"
  fi
}

install_stylua() {
  local latest
  run_spin_capture "checking latest version..." latest github_latest "JohnnyMorganz/StyLua"
  if [[ -z "$latest" ]]; then
    if command_exists stylua; then
      log_skip "StyLua $(stylua --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+') (could not check latest)"; return
    else
      log_error "StyLua" "could not resolve latest version — network down? re-run once it is back"; return
    fi
  fi
  if command_exists stylua; then
    local v; v=$(stylua --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+')
    if version_lt "$v" "$latest"; then
      log_warn "StyLua $v → upgrading to $latest"
    else
      log_skip "StyLua $v"; return
    fi
  fi
  local zip="/tmp/stylua_${latest}.zip"
  run_spin "downloading StyLua $latest..." \
    curl -fsSL "https://github.com/JohnnyMorganz/StyLua/releases/download/v${latest}/stylua-linux-${ARCH_GENERIC}.zip" -o "$zip" \
    && log_ok "downloaded StyLua $latest" || { log_error "StyLua" "download failed"; return; }
  run_spin "installing StyLua $latest..." \
    bash -c "unzip -o '$zip' -d /tmp stylua && sudo mv /tmp/stylua /usr/local/bin/stylua && rm '$zip'" \
    && log_ok "StyLua $latest installed" \
    || log_error "StyLua" "install failed"
}

# The Lua language server behind Neovim's lua_ls, which Mason used to install.
# The release is a whole tree: the binary finds main.lua and its meta files
# beside itself and writes its logs there, so it lives in ~/.local/share,
# replaced whole on upgrade, and ~/.local/bin/lua-language-server links to the
# binary. No sudo needed.
install_lua_language_server() {
  local root="$HOME/.local/share/lua-language-server" link="$HOME/.local/bin/lua-language-server"
  local latest v
  run_spin_capture "checking latest version..." latest github_latest "LuaLS/lua-language-server"
  [[ -x "$link" ]] && v=$("$link" --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+')
  if [[ -z "$latest" ]]; then
    if [[ -n "$v" ]]; then
      log_skip "lua-language-server $v (could not check latest)"
    else
      log_error "lua-language-server" "could not resolve latest version — network down? re-run once it is back"
    fi
    return
  fi
  if [[ -n "$v" ]]; then
    version_lt "$v" "$latest" || { log_skip "lua-language-server $v"; return; }
    log_warn "lua-language-server $v → upgrading to $latest"
  fi
  local tgz="$SCRIPT_TMPDIR/lua-language-server.tar.gz" new="$SCRIPT_TMPDIR/lua-language-server"
  run_spin "downloading lua-language-server $latest..." \
    curl -fsSL "https://github.com/LuaLS/lua-language-server/releases/download/${latest}/lua-language-server-${latest}-linux-${ARCH_LUALS}.tar.gz" -o "$tgz" \
    && log_ok "downloaded lua-language-server $latest" || { log_error "lua-language-server" "download failed"; return; }
  mkdir -p "$new" "$HOME/.local/share" "$HOME/.local/bin"
  if tar -xf "$tgz" -C "$new" && rm -rf "$root" && mv "$new" "$root" \
      && ln -sfn "$root/bin/lua-language-server" "$link"; then
    log_ok "lua-language-server $latest installed"
  else
    log_error "lua-language-server" "install failed"
  fi
}

# Removes the npm-global Claude Code install older versions of this script
# made. It sits in /usr/local/bin, ahead of ~/.local/bin on PATH, so it shadows
# the native one — and `claude update` can't touch it without sudo.
remove_npm_claude() {
  command_exists npm || return 0
  npm ls -g --depth=0 @anthropic-ai/claude-code &>/dev/null || return 0
  run_spin "removing npm-global Claude Code..." sudo env "PATH=$PATH" npm uninstall -g @anthropic-ai/claude-code \
    && log_ok "removed npm-global Claude Code (native install replaces it)" \
    || log_error "Claude Code" "npm uninstall failed — remove /usr/local/bin/claude by hand"
}

# Native installer (Anthropic's recommended method): a self-contained binary in
# ~/.local/share/claude, symlinked as ~/.local/bin/claude. No Node, no sudo, and
# it auto-updates in the background; the `claude update` here just catches up
# machines that haven't run it lately.
install_claude() {

  remove_npm_claude

  local bin="$HOME/.local/bin/claude"
  if [[ ! -x "$bin" ]]; then
    run_spin "installing Claude Code..." bash -c "curl -fsSL https://claude.ai/install.sh | bash" \
      && log_ok "Claude Code $("$bin" --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)" \
      || log_error "Claude Code" "install failed"
    return
  fi

  local v new
  v=$("$bin" --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)
  run_spin "checking for Claude Code updates..." "$bin" update \
    || { log_error "Claude Code" "update failed"; return; }
  new=$("$bin" --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)
  if [[ "$new" != "$v" ]]; then
    log_ok "Claude Code $v → $new"
  else
    log_skip "Claude Code $v"
  fi
}

install_vscode() {
  if command_exists code; then
    local v; v=$(code --version | head -1)
    log_skip "Visual Studio Code $v"; return
  fi
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor > /tmp/microsoft.gpg
  sudo install -D -o root -g root -m 644 /tmp/microsoft.gpg \
    /etc/apt/keyrings/packages.microsoft.gpg
  echo "deb [arch=${ARCH_DEB} signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
    | sudo tee /etc/apt/sources.list.d/vscode.list &>/dev/null
  apt_get update -qq
  run_spin "installing Visual Studio Code..." apt_get install -y code \
    && rm /tmp/microsoft.gpg \
    && log_ok "Visual Studio Code" \
    || log_error "Visual Studio Code" "install failed"
}


# ── Serial ports ─────────────────────────────────────────────────────────────────
# USB-serial adapters (ttyUSB*, ttyACM*) belong to the dialout group, so
# membership is what lets you open one without sudo or chmod. The udev rule
# drops every FTDI port's latency timer from 16 ms to 1 ms when it is plugged
# in. It is copied, not symlinked: udev reads rules.d before home directories
# are guaranteed to be mounted.
UDEV_RULES=(98-ftdi-latency.rules)

install_serial_access() {
  local groups; groups=$(id -nG "$USER")
  if [[ " $groups " == *" dialout "* ]]; then
    log_skip "$USER in dialout (serial ports open without sudo)"
  elif sudo usermod -aG dialout "$USER"; then
    log_ok "$USER added to dialout (serial ports open without sudo)"
    NEED_RESTART=true
  else
    log_error "dialout" "could not add $USER — run manually: sudo usermod -aG dialout $USER"
  fi

  local rule src dst changed=false
  for rule in "${UDEV_RULES[@]}"; do
    src="$DOTFILES/etc/udev/rules.d/$rule" dst="/etc/udev/rules.d/$rule"
    if cmp -s "$src" "$dst"; then
      log_skip "$dst"
    elif sudo install -m 644 -o root -g root "$src" "$dst"; then
      log_ok "$dst"; changed=true
    else
      log_error "$rule" "could not install into /etc/udev/rules.d"
    fi
  done
  if [[ "$changed" == true ]]; then
    sudo udevadm control --reload \
      && log_ok "udev rules reloaded (applies from the next plug-in)" \
      || log_error "udev" "reload failed — run manually: sudo udevadm control --reload"
  fi
}

# ── ser2net, for `ports share` ───────────────────────────────────────────────────
# ser2net and gensio, the library that speaks RFC 2217 for it, built from their
# newest tags into /usr/local instead of taken from apt. Ubuntu 24.04 ships
# ser2net 4.6.0 with gensio 2.8.2, which never answer an RFC 2217 PURGE-DATA:
# clients such as pyserial wait for that answer and cannot open the port.
# The unit is copied like the udev rule and left disabled.
SER2NET_UNIT=ser2net.service
SER2NET_BIN=/usr/local/sbin/ser2net
SER2NET_BUILD_DEPS=(autoconf automake libtool pkg-config libyaml-dev)
# What gensio is built without: none of it is on ser2net's serial-to-TCP path,
# and each would add a build dependency.
GENSIO_CONFIGURE=(--without-python --without-swig --without-go --without-tcl --without-glib
  --without-openipmi --without-sctp --without-pam --without-mdns --without-alsa
  --without-portaudio --without-winsound --without-udev --without-cm108gpio)

# Newest vX.Y.Z tag of GitHub repo $1. Neither project publishes GitHub
# releases, so github_latest finds nothing; tags are what they ship.
github_tag_latest() {
  git ls-remote --tags --refs "https://github.com/$1.git" 'v*' 2>/dev/null \
    | grep -oP 'refs/tags/v\K\d+\.\d+\.\d+$' | sort -V | tail -1
}

gensio_installed_version() {
  PKG_CONFIG_PATH=/usr/local/lib/pkgconfig pkg-config --modversion libgensio 2>/dev/null
}

ser2net_installed_version() {
  [[ -x "$SER2NET_BIN" ]] && "$SER2NET_BIN" -v 2>/dev/null | grep -oP '\d+\.\d+\.\d+'
}

# Builds tag v$2 of cminyard/$1 into /usr/local, configured with the rest of the
# arguments. The log is kept outside SCRIPT_TMPDIR, which is gone by the time
# anyone reads a failure.
build_from_tag() {
  local repo="$1" version="$2"; shift 2
  local src="$SCRIPT_TMPDIR/$repo" log="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/$repo-build.log"
  mkdir -p "${log%/*}"
  {
    git clone -q --depth 1 --branch "v$version" "https://github.com/cminyard/$repo.git" "$src" \
      && cd "$src" && ./reconf \
      && ./configure -q --prefix=/usr/local "$@" \
      && make -s -j"$(nproc)" \
      && sudo make -s install \
      && sudo ldconfig
  } >"$log" 2>&1 || { tail -5 "$log" >&2; echo "full log: $log" >&2; return 1; }
}

install_ser2net() {
  local missing=() dep was_active=false gensio ser2net rebuilt=false
  for dep in "${SER2NET_BUILD_DEPS[@]}"; do
    pkg_installed "$dep" || missing+=("$dep")
  done
  if (( ${#missing[@]} )); then
    run_spin "installing ${missing[*]}..." apt_get install -y "${missing[@]}" \
      && log_ok "build dependencies: ${missing[*]}" \
      || { log_error "ser2net" "apt install ${missing[*]} failed"; return; }
  fi

  systemctl is-active --quiet ser2net && was_active=true
  # Two ser2nets would fight over the unit name. apt remove, not purge, keeps
  # /etc/ser2net.yaml, which is the config `ports share` writes.
  if pkg_installed ser2net; then
    local apt_version; apt_version=$(dpkg-query -W -f='${Version}' ser2net 2>/dev/null)
    run_spin "removing apt's ser2net..." apt_get remove -y ser2net \
      && log_ok "removed apt's ser2net $apt_version (/etc/ser2net.yaml kept)" \
      || { log_error "ser2net" "apt remove ser2net failed"; return; }
  fi

  run_spin_capture "checking latest gensio..." gensio github_tag_latest cminyard/gensio
  run_spin_capture "checking latest ser2net..." ser2net github_tag_latest cminyard/ser2net
  if [[ -z "$gensio" || -z "$ser2net" ]]; then
    [[ -n "$(ser2net_installed_version)" ]] \
      && { log_skip "ser2net $(ser2net_installed_version) (could not check latest)"; return; }
    log_error "ser2net" "could not resolve latest version — network down? re-run once it is back"; return
  fi

  if needs_install "gensio" "$(gensio_installed_version)" "$gensio" ""; then
    run_spin "building gensio $gensio..." build_from_tag gensio "$gensio" "${GENSIO_CONFIGURE[@]}" \
      && { log_ok "gensio $gensio installed"; rebuilt=true; } \
      || { log_error "gensio" "build failed"; return; }
  fi
  # A new gensio is a new ABI: ser2net is rebuilt against it even when its own
  # version has not moved.
  if [[ "$rebuilt" == true ]] || needs_install "ser2net" "$(ser2net_installed_version)" "$ser2net" ""; then
    run_spin "building ser2net $ser2net..." build_from_tag ser2net "$ser2net" --sysconfdir=/etc \
      && log_ok "ser2net $ser2net installed in /usr/local/sbin" \
      || { log_error "ser2net" "build failed"; return; }
  fi

  local src="$DOTFILES/etc/systemd/system/$SER2NET_UNIT" dst="/etc/systemd/system/$SER2NET_UNIT"
  if cmp -s "$src" "$dst"; then
    log_skip "$dst"
  elif sudo install -m 644 -o root -g root "$src" "$dst" && sudo systemctl daemon-reload; then
    log_ok "$dst (disabled — ports share enables it)"
  else
    log_error "$SER2NET_UNIT" "could not install into /etc/systemd/system"; return
  fi
  # Removing apt's package stopped a share that was running; put it back.
  if [[ "$was_active" == true ]] && ! systemctl is-active --quiet ser2net; then
    sudo systemctl enable --quiet ser2net && sudo systemctl restart ser2net \
      && log_ok "ser2net restarted — still sharing, now on $(ser2net_installed_version)" \
      || log_error "ser2net" "restart failed — see: journalctl -u ser2net -n 20"
  fi
}

cmd_ser2net() {
  banner
  section "ser2net (for ports share)"
  sudo -v || { log_error "sudo" "authentication failed — cannot continue"; return 1; }
  install_ser2net
}

# ── niri desktop ───────────────────────────────────────────────────────────────
# niri (a scrollable-tiling Wayland compositor) as a second session on the login
# screen, beside GNOME. Opt-in with --niri; once it is installed, --setup keeps
# it at the versions file's pins. niri and xwayland-satellite aren't packaged
# for Ubuntu 24.04, and its Waybar (0.9.24) predates the niri modules, so all
# three are built from source; the rest comes from apt.
NIRI_BIN=/usr/local/bin/niri
NIRI_BUILD_DEPS=(gcc clang libudev-dev libgbm-dev libxkbcommon-dev libegl1-mesa-dev libwayland-dev
  libinput-dev libdbus-1-dev libsystemd-dev libseat-dev libpipewire-0.3-dev libpango1.0-dev
  libdisplay-info-dev libxcb1-dev libxcb-cursor-dev)
WAYBAR_BUILD_DEPS=(libgtkmm-3.0-dev libjsoncpp-dev libfmt-dev libspdlog-dev libgtk-layer-shell-dev
  wayland-protocols libdbusmenu-gtk3-dev libupower-glib-dev libpulse-dev libnl-3-dev libnl-genl-3-dev
  libxkbregistry-dev libevdev-dev libpam0g-dev)
# What the session runs: X11 support, launcher, notifications, lock and idle,
# wallpaper, the polkit password prompt, the media keys,
# clipboard history, night light, the sound mixer Waybar opens, and Thunar.
NIRI_SESSION_PKGS=(xwayland fuzzel mako-notifier swaylock swayidle swaybg policykit-1-gnome
  playerctl cliphist wl-clipboard wlsunset pulsemixer papirus-icon-theme thunar)
NIRI_LINKS=(
  "niri|$DOTFILES/.config/niri/config.kdl:$HOME/.config/niri/config.kdl"
  "niri|$DOTFILES/.config/waybar/config.jsonc:$HOME/.config/waybar/config.jsonc"
  "niri|$DOTFILES/.config/waybar/modules.jsonc:$HOME/.config/waybar/modules.jsonc"
  "niri|$DOTFILES/.config/waybar/style.css:$HOME/.config/waybar/style.css"
  "niri|$DOTFILES/.local/bin/power-menu:$HOME/.local/bin/power-menu"
  "niri|$DOTFILES/.local/bin/waybar-calendar:$HOME/.local/bin/waybar-calendar"
  "niri|$DOTFILES/.local/bin/xclip:$HOME/.local/bin/xclip"
  "niri|$DOTFILES/.local/bin/osd:$HOME/.local/bin/osd"
  "niri|$DOTFILES/.local/bin/lock-screen:$HOME/.local/bin/lock-screen"
  "niri|$DOTFILES/.local/bin/waybar-launch:$HOME/.local/bin/waybar-launch"
  "niri|$DOTFILES/.local/bin/battery-notify:$HOME/.local/bin/battery-notify"
)
# xwayland-satellite has no --version, so the build records what it installed.
XWS_STAMP=/usr/local/share/dotfiles/xwayland-satellite.version
# swaylock-effects is patched (patches/swaylock-effects/), and only a build
# that applied the patches writes this, so an unpatched one gets rebuilt.
SLE_STAMP=/usr/local/share/dotfiles/swaylock-effects.version

# Newest release tag of GitHub repo $1, without a leading v. github_latest only
# matches X.Y.Z, and niri numbers its releases YY.MM.
github_latest_tag() {
  curl -fsIL "https://github.com/$1/releases/latest" 2>/dev/null \
    | grep -i '^location:' | grep -oP '/tag/v?\K[0-9][0-9.]*' | tail -1
}

niri_installed_version() {
  case "$1" in
    niri)               [[ -x "$NIRI_BIN" ]] && "$NIRI_BIN" --version 2>/dev/null | awk '{print $2}' ;;
    waybar)             [[ -x /usr/local/bin/waybar ]] && /usr/local/bin/waybar --version 2>/dev/null | grep -oP 'v\K[0-9.]+' ;;
    xwayland-satellite) [[ -x /usr/local/bin/xwayland-satellite && -f "$XWS_STAMP" ]] && cat "$XWS_STAMP" ;;
    swaylock-effects)   [[ -x /usr/local/bin/swaylock && -f "$SLE_STAMP" ]] && cat "$SLE_STAMP" ;;
  esac
}

# Clones tag $3 of GitHub repo $2 and builds it; $1 names the build log. The
# tree lives under ~/.cache rather than /tmp, since niri's takes 2 GB, and is
# deleted once installed. Runs the rest of the arguments in the checkout.
build_github_tag() {
  local name="$1" repo="$2" tag="$3"; shift 3
  local cache="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles" src log
  src="$cache/build/$name"; log="$cache/$name-build.log"
  mkdir -p "$cache/build"; rm -rf "$src"
  {
    git clone -q --depth 1 --branch "$tag" "https://github.com/$repo.git" "$src" \
      && cd "$src" && "$@"
  } >"$log" 2>&1 || { tail -5 "$log" >&2; echo "full log: $log" >&2; return 1; }
  rm -rf "$src"
}

# The install steps, run inside the checkout by build_github_tag.
niri_build_install() {
  "$HOME/.cargo/bin/cargo" build --release --locked \
    && sudo install -m 755 target/release/niri resources/niri-session /usr/local/bin/ \
    && sudo install -Dm 644 resources/niri.desktop -t /usr/local/share/wayland-sessions/ \
    && sudo install -Dm 644 resources/niri-portals.conf -t /usr/local/share/xdg-desktop-portal/ \
    && sudo install -Dm 644 resources/niri.service resources/niri-shutdown.target -t /etc/systemd/user/ \
    && sudo sed -i "s|/usr/bin/niri|$NIRI_BIN|" /etc/systemd/user/niri.service
}

xws_build_install() {
  local version="$1"
  "$HOME/.cargo/bin/cargo" build --release --locked \
    && sudo install -m 755 target/release/xwayland-satellite /usr/local/bin/ \
    && sudo install -Dm 644 /dev/null "$XWS_STAMP" \
    && printf '%s\n' "$version" | sudo tee "$XWS_STAMP" >/dev/null
}

# gtk-layer-shell and spdlog are newer than 24.04 has, so meson builds them as
# subprojects; static, so nothing beyond the waybar binary lands in /usr/local.
waybar_build_install() {
  meson setup build --prefix=/usr/local --buildtype=release -Ddefault_library=static \
      -Dman-pages=disabled -Dtests=disabled \
    && ninja -C build \
    && sudo install -m 755 build/waybar /usr/local/bin/
}

# swaylock-effects: swaylock plus a clock (and effects we don't use), for
# .local/bin/lock-screen. Only the binary goes to /usr/local/bin, where it wins
# over apt's swaylock on PATH; apt's stays installed for /etc/pam.d/swaylock,
# the PAM config both use to check the password.
# The patches in patches/swaylock-effects/ are applied first; second-time-zone
# adds the extra clock line lock-screen asks for.
swaylock_effects_build_install() {
  local version="$1" patch
  for patch in "$DOTFILES"/patches/swaylock-effects/*.patch; do
    git apply "$patch" || return 1
  done
  meson setup build --buildtype=release -Dman-pages=disabled -Dgdk-pixbuf=enabled \
    && ninja -C build \
    && sudo install -m 755 build/swaylock /usr/local/bin/swaylock \
    && sudo install -Dm 644 /dev/null "$SLE_STAMP" \
    && printf '%s\n' "$version" | sudo tee "$SLE_STAMP" >/dev/null
}

# Builds one of the source-built tools when it is missing or off its pin. $1 is the versions
# file key, $2 the GitHub repo, $3 the tag prefix ("v" or nothing), $4 the step.
install_niri_component() {
  local key="$1" repo="$2" prefix="$3" step="$4" pin want have
  pin=$(tool_pin "$key")
  if [[ -n "$pin" ]]; then
    want="$pin"
  else
    run_spin_capture "checking latest $key..." want github_latest_tag "$repo"
    [[ -n "$want" ]] || { log_error "$key" "could not resolve the latest release — network down?"; return 1; }
  fi
  have=$(niri_installed_version "$key")
  needs_install "$key" "$have" "$want" "$pin" || return 0
  run_spin "building $key $want (a few minutes)..." build_github_tag "$key" "$repo" "$prefix$want" "$step" "$want" \
    && log_ok "$key $want installed in /usr/local/bin" \
    || { log_error "$key" "build failed"; return 1; }
}

# Newest stable version of crate $1 on crates.io (its API wants a User-Agent).
crates_latest() {
  curl -fsSL -A "dotfiles-install" "https://crates.io/api/v1/crates/$1" 2>/dev/null \
    | grep -oP '"max_stable_version":"\K[0-9.]+'
}

# bluetui, the Bluetooth manager Waybar opens in kitty, from crates.io: it isn't
# packaged for Ubuntu. Built in a scratch root so cargo's install records don't
# land in ~/.local, then just the binary is copied to ~/.local/bin.
install_bluetui() {
  local latest have root="$SCRIPT_TMPDIR/bluetui"
  have=$(command_exists bluetui && bluetui --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+')
  run_spin_capture "checking latest bluetui..." latest crates_latest bluetui
  if [[ -z "$latest" ]]; then
    [[ -n "$have" ]] && { log_skip "bluetui $have (could not check latest)"; return; }
    log_error "bluetui" "could not resolve the latest release — network down?"; return 1
  fi
  needs_install "bluetui" "$have" "$latest" "" || return 0
  run_spin "building bluetui $latest..." "$HOME/.cargo/bin/cargo" install --locked --root "$root" "bluetui@$latest" \
    && install -Dm 755 "$root/bin/bluetui" "$HOME/.local/bin/bluetui" \
    && log_ok "bluetui $latest installed in ~/.local/bin" \
    || { log_error "bluetui" "build failed"; return 1; }
}

# The keyboard layout is per machine, so it goes in the untracked local.kdl the
# config includes, copied from GNOME's first input source. Never overwritten.
write_niri_local() {
  local local_kdl="$HOME/.config/niri/local.kdl" layout variant src
  [[ -f "$local_kdl" ]] && { log_skip ".config/niri/local.kdl (machine-local, kept)"; return; }
  src=$(gsettings get org.gnome.desktop.input-sources sources 2>/dev/null | grep -oP "\('xkb', '\K[^']+" | head -1)
  layout="${src%%+*}"; variant=""; [[ "$src" == *+* ]] && variant="${src#*+}"
  local variant_line=""
  [[ -n "$variant" ]] && variant_line=$'\n'"            variant \"$variant\""
  mkdir -p "${local_kdl%/*}"
  cat > "$local_kdl" <<EOF
// This machine's niri settings, included by ~/.config/niri/config.kdl and not
// tracked by the dotfiles repo. The layout was copied from GNOME's.
input {
    keyboard {
        xkb {
            layout "${layout:-us}"${variant_line}
        }
    }
}

// Monitors: \`niri msg outputs\` lists them. For example:
// output "eDP-1" {
//     scale 1
//     position x=0 y=0
// }
EOF
  log_ok ".config/niri/local.kdl (keyboard layout ${layout:-us}${variant:+ $variant})"
}

# VS Code picks its secret store by recognising the desktop, and doesn't know
# niri: it then offers "weaker encryption", which would stick in GNOME too.
# Naming the store outright means the same gnome-keyring in both sessions.
# argv.json is VS Code's per-machine file (with comments), so this edits it in
# place, and only when it exists and names no store yet.
vscode_use_keyring() {
  local argv="$HOME/.vscode/argv.json"
  [[ -f "$argv" ]] || return 0
  grep -q '"password-store"' "$argv" && { log_skip "VS Code password store (already set)"; return; }
  sed -i '0,/{/s//{\n\t"password-store": "gnome-libsecret",/' "$argv" \
    && log_ok "VS Code password store → gnome-keyring (~/.vscode/argv.json)" \
    || log_error "VS Code" "could not edit ~/.vscode/argv.json"
}

# Thunar as the app for folders (xdg-open ., links to a folder), in place of
# GNOME Files: it starts at once and doesn't wait on GNOME's Tracker indexer.
# mimeapps.list is per user, so GNOME's session uses it too.
default_file_manager() {
  command_exists xdg-mime && [[ -f /usr/share/applications/thunar.desktop ]] || return 0
  [[ "$(xdg-mime query default inode/directory)" == thunar.desktop ]] \
    && { log_skip "file manager: Thunar"; return; }
  xdg-mime default thunar.desktop inode/directory \
    && log_ok "file manager → Thunar (folders, xdg-open)" \
    || log_error "file manager" "xdg-mime default failed"
}

install_niri_desktop() {
  local missing=() dep
  for dep in "${NIRI_BUILD_DEPS[@]}" "${WAYBAR_BUILD_DEPS[@]}" "${NIRI_SESSION_PKGS[@]}"; do
    pkg_installed "$dep" || missing+=("$dep")
  done
  if (( ${#missing[@]} )); then
    run_spin "installing ${#missing[@]} apt packages..." apt_get install -y "${missing[@]}" \
      && log_ok "apt: ${missing[*]}" \
      || { log_error "niri" "apt install failed: ${missing[*]}"; return 1; }
  else
    log_skip "build dependencies and session tools (apt)"
  fi
  [[ -x "$HOME/.cargo/bin/cargo" ]] || install_rust
  command_exists meson || install_uv_tool meson "Meson"

  install_niri_component niri niri-wm/niri v niri_build_install || return 1
  install_niri_component xwayland-satellite Supreeeme/xwayland-satellite v xws_build_install
  install_niri_component waybar Alexays/Waybar "" waybar_build_install
  install_niri_component swaylock-effects jirutka/swaylock-effects v swaylock_effects_build_install
  install_bluetui

  local section_l src dst
  for entry in "${NIRI_LINKS[@]}"; do
    link_parts "$entry" section_l src dst
    make_link "$src" "$dst"
  done
  write_niri_local
  ensure_login_path
  vscode_use_keyring
  default_file_manager
}

cmd_niri() {
  echo
  banner
  section "niri desktop"
  # sudo -n first: with a NOPASSWD rule, sudo -v can still insist on a password.
  sudo -n true 2>/dev/null || sudo -v || { log_error "sudo" "authentication failed — cannot continue"; return 1; }
  # The builds take longer than sudo's timestamp lasts.
  ( while kill -0 "$$" 2>/dev/null; do sudo -n true; sleep 50; done ) &>/dev/null &
  SUDO_KEEPALIVE_PID=$!
  install_niri_desktop || return 1

  # The theme files need niri on PATH to be linked, so apply the saved theme
  # again now that it is.
  local family="catppuccin" variant="mocha"
  [[ -f "$HOME/.config/theme/current" ]] && read -r family variant < "$HOME/.config/theme/current"
  section "Theme"
  apply_theme "$family" "$variant"

  echo
  if (( FAIL_COUNT > 0 )); then
    echo -e "\r\033[K  ${RED}${BOLD}Done with ${FAIL_COUNT} error(s).${RESET} ${SUBTEXT}See the ✗ lines above.${RESET}"
  else
    echo -e "\r\033[K  ${MAUVE}${BOLD}Done!${RESET} ${TEXT}Log out, pick niri from the gear on the login screen. Super+Shift+/ lists the keys.${RESET}"
  fi
  echo
}

# Prompts "<label> [<default>]: " and stores the reply, or the default when the
# reply is empty, in the variable named by $3.
ask_default() {
  local label="$1" default="$2" reply
  if [[ -n "$default" ]]; then
    printf "\r\033[K  ${TEXT}%s [%s]: ${RESET}" "$label" "$default"
  else
    printf "\r\033[K  ${TEXT}%s: ${RESET}" "$label"
  fi
  reset_tty_for_read; read -r reply
  printf -v "$3" '%s' "${reply:-$default}"
}

# Copies a profile template to its machine-local file. People edit that file
# afterwards, so one that no longer matches the template is replaced only on a
# yes. install -m 600: a copy would keep the template's group-write bit, and
# ssh refuses to read an included file that has it.
install_profile_file() {
  local profile="$1" src="$2" dst="$3"
  local name="${dst#"$HOME/"}" reply
  if [[ -f "$dst" ]] && ! cmp -s "$src" "$dst"; then
    printf "\r\033[K  ${TEXT}%s differs from the %s template. Replace it? [y/N] ${RESET}" "$name" "$profile"
    reset_tty_for_read; read -r reply
    [[ "$reply" =~ ^[Yy]$ ]] || { log_skip "$name kept as it is"; return; }
  fi
  install -m 600 "$src" "$dst"
  log_ok "$name set to $profile profile"
}

# Name and email are asked for rather than built in, so anyone can run this.
# The profile only picks which ~/.zshrc.local and ~/.ssh/config.local templates
# to start from.
configure_identity() {
  section "Identity"

  local cfg="$HOME/.gitconfig.local" current_name="" current_email=""
  if [[ -f "$cfg" ]]; then
    current_name=$(git config --file "$cfg" user.name 2>/dev/null)
    current_email=$(git config --file "$cfg" user.email 2>/dev/null)
  fi

  # A file written before user.name moved out of .gitconfig has only the
  # email, so it falls through to the prompts instead of being skipped.
  if [[ -n "$current_name" && -n "$current_email" ]]; then
    log_skip "already configured as $current_name <$current_email>"
    printf "\r\033[K  ${TEXT}Change it? [y/N] ${RESET}"
    local reply; reset_tty_for_read; read -r reply
    [[ "$reply" =~ ^[Yy]$ ]] || return
  fi

  # First run: offer the full name from the account's GECOS field.
  [[ -n "$current_name" ]] || current_name=$(getent passwd "$USER" | cut -d: -f5 | cut -d, -f1)

  local name email
  ask_default "Git name" "$current_name" name
  ask_default "Git email" "$current_email" email
  [[ -n "$name" ]] || { log_warn "no name given — skipping"; return; }
  [[ "$email" == ?*@?* ]] || { log_warn "'$email' is not an email address — skipping"; return; }

  echo -e "\r\033[K  ${TEXT}Select profile:${RESET}"
  echo -e "\r\033[K    ${GREEN}1)${RESET} ${TEXT}personal${RESET}"
  echo -e "\r\033[K    ${GREEN}2)${RESET} ${TEXT}work      — adds a local-network SSH block${RESET}"
  printf "\r\033[K  ${TEXT}Choice [1/2]: ${RESET}"

  local choice profile; reset_tty_for_read; read -r choice
  case "$choice" in
    1) profile="personal" ;;
    2) profile="work" ;;
    *) log_warn "invalid choice — skipping"; return ;;
  esac

  # git config --file sets only these two keys, so anything else kept in the
  # file (a signing key, say) survives, and it quotes the name correctly.
  git config --file "$cfg" user.name "$name"
  git config --file "$cfg" user.email "$email"
  log_ok "git identity set to $name <$email>"

  install_profile_file "$profile" "$DOTFILES/.zshrc.local.$profile" "$HOME/.zshrc.local"

  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
  install_profile_file "$profile" "$DOTFILES/.ssh/config.local.$profile" "$HOME/.ssh/config.local"
}

apply_theme() {
  local family="$1" variant="$2"
  local stub label delta_feature

  case "$family" in
    catppuccin)
      local cap; cap="$(tr '[:lower:]' '[:upper:]' <<<"${variant:0:1}")${variant:1}"
      stub="$variant"
      label="Catppuccin $cap"
      delta_feature="catppuccin-$variant"
      ;;
    gruvbox)
      local vcap; vcap="$(tr '[:lower:]' '[:upper:]' <<<"${variant:0:1}")${variant:1}"
      stub="gruvbox-$variant"
      label="Gruvbox $vcap"
      delta_feature="gruvbox-$variant"
      ;;
    dracula)
      # Single-variant theme — no light/dark split, so no variant suffix on
      # filenames/labels (unlike gruvbox, which reserves room for one).
      stub="dracula"
      label="Dracula"
      delta_feature="dracula"
      ;;
  esac

  mkdir -p "$HOME/.config/kitty" "$HOME/.config/bat" "$HOME/.config/fzf" "$HOME/.config/eza" \
    "$HOME/.config/btop/themes" "$HOME/.config/zsh-syntax-highlighting" "$HOME/.config/lazygit" \
    "$HOME/.config/p10k" "$HOME/.config/yazi"

  # Each pointer is a per-machine symlink in $HOME pointing at a repo file.
  local pointers=(
    "$DOTFILES/.config/kitty/${stub}.conf:$HOME/.config/kitty/current-theme.conf:kitty theme → ${label}"
    "$DOTFILES/.config/bat/config.${stub}:$HOME/.config/bat/config:bat theme → ${label}"
    "$DOTFILES/.config/fzf/${stub}.sh:$HOME/.config/fzf/active.sh:fzf theme → ${label}"
    "$DOTFILES/.config/eza/${stub}.yml:$HOME/.config/eza/theme.yml:eza theme → ${label}"
    "$DOTFILES/.config/btop/themes/${stub}.theme:$HOME/.config/btop/themes/active.theme:btop theme → ${label}"
    "$DOTFILES/.config/zsh-syntax-highlighting/${stub}.zsh:$HOME/.config/zsh-syntax-highlighting/active.zsh:zsh-syntax-highlighting theme → ${label}"
    "$DOTFILES/.config/lazygit/${stub}.yml:$HOME/.config/lazygit/active-theme.yml:lazygit theme → ${label}"
    "$DOTFILES/.config/p10k/${stub}.zsh:$HOME/.config/p10k/active.zsh:Powerlevel10k theme → ${label}"
    "$DOTFILES/.config/yazi/${stub}.toml:$HOME/.config/yazi/theme.toml:yazi theme → ${label}"
  )
  # The niri session's own tools, only where --niri installed it.
  if [[ -x "$NIRI_BIN" ]]; then
    mkdir -p "$HOME/.config/niri" "$HOME/.config/waybar" "$HOME/.config/fuzzel" \
      "$HOME/.config/mako" "$HOME/.config/swaylock"
    pointers+=(
      "$DOTFILES/.config/niri/${stub}.kdl:$HOME/.config/niri/theme.kdl:niri theme → ${label}"
      "$DOTFILES/.config/waybar/${stub}.css:$HOME/.config/waybar/theme.css:Waybar theme → ${label}"
      "$DOTFILES/.config/fuzzel/${stub}.ini:$HOME/.config/fuzzel/fuzzel.ini:fuzzel theme → ${label}"
      "$DOTFILES/.config/mako/${stub}.conf:$HOME/.config/mako/config:mako theme → ${label}"
      "$DOTFILES/.config/swaylock/${stub}.conf:$HOME/.config/swaylock/config:swaylock theme → ${label}"
      "$DOTFILES/.config/niri/wallpapers/${stub}.svg:$HOME/.config/niri/wallpaper.svg:wallpaper → ${label}"
    )
  fi

  for entry in "${pointers[@]}"; do
    local target="${entry%%:*}" rest="${entry#*:}"
    local link="${rest%%:*}" plabel="${rest#*:}"
    rm -f "$link"
    if ln -s "$target" "$link"; then
      log_ok "${SUBTEXT}$plabel${RESET}"
    else
      log_error "$plabel" "could not symlink $link"
    fi
  done

  # btop.conf is machine-local (btop rewrites it on exit), so it can't be
  # symlinked from the repo like the others — just set the two keys that
  # matter instead of the whole file: color_theme points at the "active"
  # symlink above, and theme_background off lets kitty's translucent
  # background show through btop the way it does everywhere else.
  local btop_conf="$HOME/.config/btop/btop.conf" key value
  for key in color_theme theme_background; do
    case "$key" in
      color_theme)      value='"active"' ;;
      theme_background) value=false ;;
    esac
    if [[ -f "$btop_conf" ]] && grep -q "^$key" "$btop_conf"; then
      sed -i "s/^$key.*/$key = $value/" "$btop_conf"
    else
      printf '%s = %s\n' "$key" "$value" >> "$btop_conf"
    fi
  done
  log_ok "${SUBTEXT}btop color_theme → active, theme background off${RESET}"

  # delta's theme goes in an untracked file that .gitconfig includes last, so
  # picking a theme leaves the repo's .gitconfig unchanged.
  mkdir -p "$HOME/.config/delta"
  printf '[delta]\n\tfeatures = %s\n' "$delta_feature" > "$HOME/.config/delta/theme.gitconfig" \
    && log_ok "${SUBTEXT}delta theme → ${label}${RESET}" \
    || log_error "delta theme" "could not write ~/.config/delta/theme.gitconfig"

  command_exists bat && bat cache --build &>/dev/null

  # GTK apps (Settings, Files, dialogs) in the Yaru accent closest to the
  # theme, and Papirus icons where installed (--niri installs them). Both are
  # GNOME-wide settings, so GNOME follows too.
  if command_exists gsettings; then
    local yaru=purple
    [[ "$family" == gruvbox ]] && yaru=olive
    if [[ -d "/usr/share/themes/Yaru-$yaru-dark" ]]; then
      gsettings set org.gnome.desktop.interface gtk-theme "Yaru-$yaru-dark" \
        && log_ok "${SUBTEXT}GTK theme → Yaru-$yaru-dark${RESET}"
    fi
    if [[ -d /usr/share/icons/Papirus-Dark ]]; then
      gsettings set org.gnome.desktop.interface icon-theme Papirus-Dark \
        && log_ok "${SUBTEXT}icon theme → Papirus-Dark${RESET}"
    fi
  fi

  # niri reloads its own config; a running Waybar and mako need telling, and
  # swaybg restarting on the new wallpaper (through niri, so it stays in the
  # session rather than tied to this terminal).
  pkill -USR2 -x waybar 2>/dev/null
  command_exists makoctl && makoctl reload &>/dev/null
  if [[ -n "$NIRI_SOCKET" ]] && pgrep -x swaybg >/dev/null; then
    pkill -x swaybg
    niri msg action spawn-sh -- 'exec swaybg -m fill -i ~/.config/niri/wallpaper.svg' &>/dev/null
  fi
  return 0
}

configure_theme() {
  section "Theme"

  local theme_file="$HOME/.config/theme/current"
  local legacy_file="$HOME/.config/catppuccin/flavor"
  local family="" variant=""

  if [[ -f "$theme_file" ]]; then
    read -r family variant < "$theme_file"
  elif [[ -f "$legacy_file" ]]; then
    # Migrate from the old Catppuccin-only state file.
    family="catppuccin"; variant=$(<"$legacy_file")
  fi

  # Latte and Gruvbox Light were dropped — fall back rather than pointing at
  # files that no longer exist if an old state file still names one of them.
  [[ "$family" == "catppuccin" && "$variant" == "latte" ]] && variant="mocha"
  [[ "$family" == "gruvbox" && "$variant" == "light" ]] && variant="dark"

  if [[ -n "$family" && -n "$variant" ]]; then
    log_skip "currently set to $family $variant"
    printf "\r\033[K  ${TEXT}Change it? [y/N] ${RESET}"
    local reply; reset_tty_for_read; read -r reply
    if [[ ! "$reply" =~ ^[Yy]$ ]]; then
      apply_theme "$family" "$variant"
      return
    fi
  fi

  echo -e "\r\033[K  ${TEXT}Select theme:${RESET}"
  echo -e "\r\033[K    ${GREEN}1)${RESET} ${TEXT}Catppuccin Frappé${RESET}"
  echo -e "\r\033[K    ${GREEN}2)${RESET} ${TEXT}Catppuccin Macchiato${RESET}"
  echo -e "\r\033[K    ${GREEN}3)${RESET} ${TEXT}Catppuccin Mocha${RESET}"
  echo -e "\r\033[K    ${GREEN}4)${RESET} ${TEXT}Gruvbox Dark${RESET}"
  echo -e "\r\033[K    ${GREEN}5)${RESET} ${TEXT}Dracula${RESET}"
  printf "\r\033[K  ${TEXT}Choice [1-5]: ${RESET}"

  local choice; reset_tty_for_read; read -r choice
  case "$choice" in
    1) family="catppuccin"; variant="frappe" ;;
    2) family="catppuccin"; variant="macchiato" ;;
    3) family="catppuccin"; variant="mocha" ;;
    4) family="gruvbox";    variant="dark" ;;
    5) family="dracula";    variant="dark" ;;
    *) log_warn "invalid choice — defaulting to Catppuccin Mocha"; family="catppuccin"; variant="mocha" ;;
  esac

  mkdir -p "$(dirname "$theme_file")"
  printf '%s %s\n' "$family" "$variant" > "$theme_file"
  rm -f "$legacy_file"
  log_ok "theme saved: $family $variant"

  apply_theme "$family" "$variant"
}

set_default_terminal() {
  section "Default terminal"
  local kitty_bin="$HOME/.local/kitty.app/bin/kitty"

  if ! command_exists gsettings; then
    log_warn "gsettings not found — skipping (not a GNOME session?)"; return
  fi

  local current; current=$(gsettings get org.gnome.desktop.default-applications.terminal exec 2>/dev/null | tr -d "'")
  if [[ "$current" == "$kitty_bin" ]]; then
    log_skip "Kitty (already default terminal)"; return
  fi

  gsettings set org.gnome.desktop.default-applications.terminal exec "$kitty_bin" \
    && gsettings set org.gnome.desktop.default-applications.terminal exec-arg '-e' \
    && log_ok "Kitty set as default terminal" \
    || log_warn "could not set default terminal — run manually: gsettings set org.gnome.desktop.default-applications.terminal exec '$kitty_bin'"
}

# The account's login shell, not $SHELL: $SHELL keeps the old value for the
# rest of the session, so a re-run before logging out would change it again.
# Through sudo, whose credential is still cached from the start of --setup:
# plain chsh asks for the password itself, and with its output hidden that
# prompt was invisible and the run looked hung.
set_default_shell() {
  section "Default shell"
  local zsh_bin; zsh_bin=$(command -v zsh)
  if [[ "$(getent passwd "$USER" | cut -d: -f7)" == "$zsh_bin" ]]; then
    log_skip "Zsh (already default)"; return
  fi
  if sudo chsh -s "$zsh_bin" "$USER" >/dev/null; then
    log_ok "Zsh set as default shell"
    NEED_RESTART=true
  else
    log_warn "could not change shell — run manually: chsh -s \$(which zsh)"
  fi
}

# ── Commands ───────────────────────────────────────────────────────────────────

# ── Verification ───────────────────────────────────────────────────────────────
# Every step above reports what it *did*, which is not the same as the result
# working. These checks exercise the tools instead of just looking for them on
# PATH — compile and run real code, cross-compile for bare-metal Arm, drive clangd,
# build a throwaway CMake project — so a PATH collision, a half-extracted tree
# or a binary missing a shared library surfaces here rather than in the middle
# of real work days later. Two real regressions this would have caught
# immediately: apt's arm-none-eabi-gcc shadowing the newer /opt one, and
# upstream's lldb being unable to start for want of libpython3.11.
#
# Nothing here needs sudo, deliberately — it runs after cmd_setup drops the
# sudo keepalive, and must not re-prompt for a password at the very end.
# Failures go through log_error, so they count toward FAIL_COUNT and the exit
# status, and a --setup run can't report success over a broken toolchain.

VERIFY_LABEL_W=18
VERIFY_TMP=""

# Runs one check behind a spinner and prints a single aligned line. The check's
# stdout becomes the trailing detail on success and the reason on failure, so
# each verify_* below is simply "do the thing, echo a one-line summary".
vcheck() {
  local label="$1"; shift
  local out padded
  padded=$(printf "%-${VERIFY_LABEL_W}s" "$label")
  if run_spin_capture "checking ${label}..." out "$@"; then
    out="${out%%$'\n'*}"
    log_ok "${padded}${out:+ — ${out}}"
  else
    out="${out%%$'\n'*}"
    log_error "$padded" "${out:-check failed}"
  fi
}

# First/last meaningful line of a captured error, with bash's "script: line N:"
# prefix stripped so the reason reads as the tool's own message rather than as
# an install.sh backtrace. Blank lines are dropped — compilers like to emit
# them around diagnostics.
verify_err()      { sed 's/^[^:]*: line [0-9]*: //' "$1" 2>/dev/null | grep -v '^[[:space:]]*$' | head -1; }
verify_err_last() { sed 's/^[^:]*: line [0-9]*: //' "$1" 2>/dev/null | grep -v '^[[:space:]]*$' | tail -1; }

verify_versions() {
  local t
  for t in gcc g++ clang clang++ cmake ninja arm-none-eabi-gcc; do
    command_exists "$t" || { echo "$t not found on PATH"; return 1; }
  done
  # A pin that isn't what's installed means a build here no longer matches
  # the other machines. LLVM's pin is checked in verify_clang_tools.
  local key pin have off=""
  for key in arm-gcc cmake ninja uv clang; do
    pin=$(tool_pin "$key"); [[ -n "$pin" ]] || continue
    have=$(tool_installed_version "$key")
    [[ "$have" == "$pin" ]] || off+="$key ${have:-missing} (pinned $pin), "
  done
  [[ -z "$off" ]] || { echo "not at the pinned version: ${off%, } — run ./install.sh --setup"; return 1; }
  local pinned=""; [[ -n "$(llvm_pin)" ]] && pinned=" (pinned)"
  printf 'gcc %s · clang %s%s · cmake %s · ninja %s · arm %s' \
    "$(gcc -dumpfullversion 2>/dev/null)" \
    "$(clang --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)" "$pinned" \
    "$(cmake --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+')" \
    "$(ninja --version 2>/dev/null)" \
    "$(arm-none-eabi-gcc -dumpfullversion 2>/dev/null)"
}

# Compiles AND runs, asserting the exit code: a toolchain can link a binary
# that dies instantly on a missing shared library, which a compile-only check
# reports as success.
verify_native_compile() {
  local d="$VERIFY_TMP" cc rc
  for cc in gcc clang; do
    "$cc" "$d/t.c" -o "$d/native" 2>"$d/err" || { echo "$cc: $(verify_err "$d/err")"; return 1; }
    "$d/native"; rc=$?
    (( rc == 42 )) || { echo "$cc built a binary that exited $rc, expected 42"; return 1; }
  done
  for cc in g++ clang++; do
    "$cc" "$d/t.cpp" -o "$d/native" 2>"$d/err" || { echo "$cc: $(verify_err "$d/err")"; return 1; }
    "$d/native"; rc=$?
    (( rc == 42 )) || { echo "$cc built a binary that exited $rc, expected 42"; return 1; }
  done
  clang -fuse-ld=lld "$d/t.c" -o "$d/native" 2>"$d/err" \
    || { echo "clang -fuse-ld=lld: $(verify_err "$d/err")"; return 1; }
  echo 'gcc, g++, clang, clang++ compile and run; lld links'
}

verify_arm_cross() {
  local d="$VERIFY_TMP"
  arm-none-eabi-gcc -c "$d/arm.c" -o "$d/arm.o" 2>"$d/err" \
    || { echo "compile: $(verify_err "$d/err")"; return 1; }
  # --specs=nosys.specs links against newlib with syscall stubs, which is what
  # proves the bundled libc and its headers actually came out of the tarball.
  arm-none-eabi-gcc --specs=nosys.specs "$d/arm.c" -o "$d/arm.elf" 2>"$d/err" \
    || { echo "newlib link: $(verify_err "$d/err")"; return 1; }
  command_exists arm-none-eabi-gdb || { echo 'arm-none-eabi-gdb not on PATH'; return 1; }
  echo "bare-metal object + newlib link ($(arm-none-eabi-size "$d/arm.elf" 2>/dev/null | awk 'NR==2{print $1}') bytes .text), gdb present"
}

verify_clang_tools() {
  local d="$VERIFY_TMP"
  # A pin that isn't the active version means something upgraded past it — an
  # older checkout's --setup, or a hand-edited pin file. Worth failing on: the
  # editors and every build would silently be using a version work declined.
  local pin; pin=$(llvm_pin)
  if [[ -n "$pin" ]]; then
    local active; active=$(llvm_installed_version)
    [[ "$active" == "$pin" ]] \
      || { echo "LLVM is pinned to $pin but /opt/llvm is ${active:-unset} — run ./install.sh --llvm $pin"; return 1; }
  fi
  clangd --check="$d/t.cpp" >"$d/err" 2>&1 || { echo 'clangd --check failed to parse a plain C++ file'; return 1; }
  printf 'int  main( ){return 0 ;}\n' | clang-format >/dev/null 2>"$d/err" \
    || { echo "clang-format: $(verify_err "$d/err")"; return 1; }
  clang-tidy --version >/dev/null 2>&1 || { echo 'clang-tidy will not run'; return 1; }
  if command_exists lldb; then
    lldb --batch -o quit >/dev/null 2>"$d/err" || { echo "lldb will not start: $(verify_err "$d/err")"; return 1; }
  fi
  echo 'clangd parses, clang-format formats, clang-tidy and lldb run'
}

# bindgen, bpftrace and anything else driving the libclang C API resolve their
# builtin headers (limits.h, stddef.h, …) from the *library's* own install
# prefix — not from the clang driver on PATH. So libclang can be installed and
# loadable while its headers are absent, and nothing complains until a
# downstream build dies with "'limits.h' file not found". That is exactly what
# happened here: removing the apt LLVM 18 tooling took libclang-common-18-dev
# (which owns /usr/lib/llvm-18/lib/clang/18/include) while libclang1-18 stayed
# behind for bpftrace, and a Rust bindgen build broke. Checking the driver
# alone does not catch this, hence a check per libclang install.
# Only the NEWEST apt libclang is checked, because that is the one a
# version-agnostic consumer picks up. Older runtime-only libclangs are left
# alone on purpose: Ubuntu ships libclang1-15 for qdoc-qt5 with no
# libclang-common-15-dev and no lib/clang tree at all, which is correct for
# that package and would otherwise be a permanent false failure here.
verify_libclang() {
  local newest dir report=""
  # shellcheck disable=SC2010  # the names are libclang-<major>.so*, nothing exotic
  newest=$(ls /usr/lib/x86_64-linux-gnu/libclang-*.so* 2>/dev/null \
    | grep -oP '(?<=libclang-)\d+' | sort -n | tail -1)
  if [[ -n "$newest" ]]; then
    dir=$(ls -d "/usr/lib/llvm-${newest}/lib/clang/"*/include 2>/dev/null | head -1)
    [[ -n "$dir" && -f "$dir/limits.h" ]] \
      || { echo "libclang-${newest} cannot find its builtin headers — install libclang-common-${newest}-dev"; return 1; }
    report="apt libclang-${newest}"
  fi
  if [[ -e /opt/llvm/lib/libclang.so ]]; then
    dir=$(ls -d /opt/llvm/lib/clang/*/include 2>/dev/null | head -1)
    [[ -n "$dir" && -f "$dir/limits.h" ]] \
      || { echo '/opt/llvm libclang is missing its builtin headers — the tarball extracted incompletely'; return 1; }
    report="${report:+$report + }/opt/llvm"
  fi
  [[ -n "$report" ]] || { echo 'no libclang found on the system'; return 1; }

  # A file-existence check cannot catch the failure that actually happened:
  # /opt/llvm's headers were present the whole time, but libclang could not
  # resolve them at runtime once clang-sys loaded it via `llvm-config --libdir`.
  # The enforceable invariant is therefore about llvm-config itself — our tree's
  # copy must stay off PATH. A distro llvm-config (/usr/bin, matching apt's
  # libclang) is fine and deliberately allowed.
  if command_exists llvm-config; then
    local cfg; cfg=$(readlink -f "$(command -v llvm-config)")
    [[ "$cfg" != /opt/* ]] \
      || { echo "llvm-config on PATH resolves into ${cfg%/bin/*} — it redirects clang-sys/CMake LLVM discovery there and breaks bindgen builds; remove /usr/local/bin/llvm-config"; return 1; }
  fi

  echo "${report} resolve limits.h/stddef.h; no /opt llvm-config shadowing discovery"
}

verify_cmake_ninja() {
  local d="$VERIFY_TMP/proj"
  mkdir -p "$d" || return 1
  printf 'cmake_minimum_required(VERSION 3.20)\nproject(verify C)\nadd_executable(verify main.c)\n' > "$d/CMakeLists.txt"
  cp "$VERIFY_TMP/t.c" "$d/main.c"
  cmake -S "$d" -B "$d/build" -G Ninja >"$VERIFY_TMP/err" 2>&1 \
    || { echo "configure: $(verify_err_last "$VERIFY_TMP/err")"; return 1; }
  cmake --build "$d/build" >"$VERIFY_TMP/err" 2>&1 \
    || { echo "build: $(verify_err_last "$VERIFY_TMP/err")"; return 1; }
  [[ -x "$d/build/verify" ]] || { echo 'build reported success but produced no binary'; return 1; }
  echo 'configured and built a throwaway project with the Ninja generator'
}

verify_cli_tools() {
  local d="$VERIFY_TMP" t
  for t in bat delta fzf rg fd jq eza zoxide direnv dust duf yazi btop lazygit glab gh tree-sitter bw uv nvim ports git-lfs lua-language-server difft just; do
    command_exists "$t" || { echo "$t not found on PATH"; return 1; }
  done
  # On PATH is not enough: a prebuilt linked against a newer glibc than the
  # host's is found fine and then dies on startup.
  tree-sitter --version >/dev/null 2>&1        || { echo "tree-sitter won't run: $(tree-sitter --version 2>&1 | head -1)"; return 1; }
  bw --version >/dev/null 2>&1                 || { echo "bw won't run: $(bw --version 2>&1 | head -1)"; return 1; }
  uv --version >/dev/null 2>&1                 || { echo "uv won't run: $(uv --version 2>&1 | head -1)"; return 1; }
  for t in dust duf yazi glab gh difft just; do
    "$t" --version >/dev/null 2>&1             || { echo "$t won't run: $("$t" --version 2>&1 | head -1)"; return 1; }
  done
  direnv version >/dev/null 2>&1               || { echo "direnv won't run: $(direnv version 2>&1 | head -1)"; return 1; }
  rg -q needle "$d/hay"                        || { echo 'rg matched nothing in a file that contains the pattern'; return 1; }
  [[ -n "$(fd -t f hay "$d" 2>/dev/null)" ]]   || { echo 'fd found no file that exists'; return 1; }
  printf '{"a":1}' | jq -e '.a == 1' >/dev/null 2>&1 || { echo 'jq filter returned the wrong result'; return 1; }
  printf 'x\n' | bat --plain >/dev/null 2>&1   || { echo 'bat failed to render'; return 1; }
  printf 'a\nb\n' | fzf --filter=a >/dev/null 2>&1 || { echo 'fzf --filter failed'; return 1; }
  eza "$d" >/dev/null 2>&1                     || { echo 'eza failed to list a directory'; return 1; }
  nvim --headless +q >/dev/null 2>&1           || { echo 'nvim failed to start headless'; return 1; }
  ports >/dev/null 2>&1                        || { echo "ports failed: $(ports 2>&1 | head -1)"; return 1; }
  # kitty --version runs without them; only opening a window loads the GLFW
  # backends, so a missing X11/Wayland library shows up only at first launch.
  local so missing
  for so in "$HOME"/.local/kitty.app/lib/kitty-extensions/kitty.glfw-*.so; do
    [[ -e "$so" ]] || continue
    missing=$(ldd "$so" 2>/dev/null | awk '/not found/ {print $1}' | tr '\n' ' ')
    [[ -z "$missing" ]] || { echo "kitty cannot open a window: ${missing% } missing (run --setup)"; return 1; }
  done
  git lfs version >/dev/null 2>&1              || { echo "git-lfs won't run: $(git lfs version 2>&1 | head -1)"; return 1; }
  lua-language-server --version >/dev/null 2>&1 || { echo "lua-language-server won't run: $(lua-language-server --version 2>&1 | head -1)"; return 1; }
  echo 'bat, delta, fzf, rg, fd, jq, eza, zoxide, direnv, dust, duf, yazi, btop, lazygit, glab, gh, tree-sitter, bw, uv, nvim, ports, git-lfs, lua-language-server, difft, just all run; kitty can open a window'
}

# A plugin off its pinned commit means this shell runs different plugin code
# from the other machines.
verify_zsh_plugins() {
  local custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}" rel name pin have off="" pinned=0
  for rel in "${!OMZ_REPOS[@]}"; do
    name=$(basename "$rel")
    [[ -d "$custom/$rel/.git" ]] || { echo "$name is not installed (run --setup)"; return 1; }
    pin=$(tool_pin "$name"); [[ -n "$pin" ]] || continue
    have=$(git -C "$custom/$rel" rev-parse HEAD 2>/dev/null)
    [[ "$have" == "$pin" ]] || off+="$name ${have:0:7} (pinned ${pin:0:7}), "
    (( ++pinned ))
  done
  [[ -z "$off" ]] || { echo "not at the pinned commit: ${off%, } — run ./install.sh --setup"; return 1; }
  local plugins=$(( ${#OMZ_REPOS[@]} - 1 ))
  if (( pinned == ${#OMZ_REPOS[@]} )); then
    echo "Powerlevel10k and $plugins plugins at their pinned commits"
  else
    echo "Powerlevel10k and $plugins plugins installed; $pinned at their pinned commits, the rest track latest"
  fi
}

# A dangling symlink is the signature failure of this install model: /opt trees
# are replaced wholesale on upgrade, so anything still pointing into an old
# versioned path silently breaks. The stable /opt/{llvm,cmake,arm-gcc} aliases
# exist to prevent exactly this; this check is what proves they are working.
verify_symlinks() {
  local d l broken=0 list=""
  for d in "$HOME/.local/bin" /usr/local/bin /opt/arm-gcc/bin /opt/llvm/bin /opt/cmake/bin; do
    [[ -d "$d" ]] || continue
    while IFS= read -r l; do
      [[ -n "$l" ]] || continue
      broken=$(( broken + 1 )); list+="$(basename "$l") "
    done < <(find "$d" -maxdepth 1 -xtype l 2>/dev/null)
  done
  (( broken == 0 )) || { echo "${broken} dangling: ${list% }"; return 1; }
  echo 'no dangling links in ~/.local/bin, /usr/local/bin or /opt'
}

# install.sh is ~2,700 lines of bash that nothing else exercises line by line, so
# lint it here: a bug like `local a="$1" b="$a"` passes bash -n and every smoke
# test, and just quietly never does its job. Warnings and up only; style and info
# notes are advice, not defects.
verify_shell_lint() {
  command_exists shellcheck || { echo 'shellcheck not found on PATH (run --setup)'; return 1; }
  local out; out=$(shellcheck -S warning -f gcc "$DOTFILES/install.sh" 2>&1)
  [[ -z "$out" ]] || { echo "$(wc -l <<<"$out") shellcheck warning(s), first: $(head -1 <<<"$out" | sed "s|^$DOTFILES/||")"; return 1; }
  echo 'install.sh passes shellcheck (warnings and up)'
}

# The group database, not `id -nG` with no argument: a user added during this
# --setup run is a member from the next login, and the check should already
# pass rather than tell them to fix what --setup just did.
verify_serial_access() {
  local rule
  [[ " $(id -nG "$USER") " == *" dialout "* ]] \
    || { echo "$USER not in dialout (run --setup)"; return 1; }
  for rule in "${UDEV_RULES[@]}"; do
    cmp -s "$DOTFILES/etc/udev/rules.d/$rule" "/etc/udev/rules.d/$rule" \
      || { echo "/etc/udev/rules.d/$rule missing or out of date (run --setup)"; return 1; }
  done
  echo 'in dialout; FTDI latency rule installed'
}

# The source build, not apt's: the package's 4.6.0 is what this replaces, and
# both at once would fight over the unit.
verify_ser2net() {
  local v; v=$(ser2net_installed_version)
  [[ -n "$v" ]] || { echo "$SER2NET_BIN missing (run --ser2net)"; return 1; }
  ! pkg_installed ser2net || { echo "apt's ser2net is installed beside the source build (run --ser2net)"; return 1; }
  cmp -s "$DOTFILES/etc/systemd/system/$SER2NET_UNIT" "/etc/systemd/system/$SER2NET_UNIT" \
    || { echo "/etc/systemd/system/$SER2NET_UNIT missing or out of date (run --ser2net)"; return 1; }
  echo "ser2net $v (gensio $(gensio_installed_version)) from source; unit installed"
}

# Only run where --niri installed it: the three source builds are present and
# the config, with its theme and local includes, parses.
verify_niri() {
  local key v versions=""
  for key in niri xwayland-satellite waybar swaylock-effects; do
    v=$(niri_installed_version "$key")
    [[ -n "$v" ]] || { echo "$key missing (run --niri)"; return 1; }
    versions+="$key $v, "
  done
  "$NIRI_BIN" validate &>/dev/null || { echo ".config/niri/config.kdl does not parse (niri validate)"; return 1; }
  echo "${versions%, }; config valid"
}

# dpkg -C rather than `apt-get check` on purpose: it needs no sudo, and this
# runs after the keepalive is dropped.
verify_dpkg_state() {
  local out; out=$(dpkg -C 2>&1)
  [[ -z "$out" ]] || { echo 'dpkg reports half-configured or broken packages'; return 1; }
  echo 'package database consistent, nothing half-configured'
}

verify_install() {
  section "Verification"
  VERIFY_TMP=$(mktemp -d -p "$SCRIPT_TMPDIR") || { log_error "Verification" "could not create a temp directory"; return; }

  # Fixtures shared by several checks. main() returns 42 so the compile checks
  # can tell "ran correctly" apart from "exited 0 because it never ran".
  printf 'int main(void){return 42;}\n' > "$VERIFY_TMP/t.c"
  printf '#include <vector>\nint main(){std::vector<int> v{1,2};return v.size()==2?42:1;}\n' > "$VERIFY_TMP/t.cpp"
  printf 'int main(void){return 0;}\n' > "$VERIFY_TMP/arm.c"
  printf 'needle\n' > "$VERIFY_TMP/hay"

  vcheck "toolchains"        verify_versions
  vcheck "native compile"    verify_native_compile
  vcheck "ARM cross-compile" verify_arm_cross
  vcheck "clang tools"       verify_clang_tools
  vcheck "libclang"          verify_libclang
  vcheck "cmake + ninja"     verify_cmake_ninja
  vcheck "CLI tools"         verify_cli_tools
  vcheck "zsh plugins"       verify_zsh_plugins
  vcheck "symlinks"          verify_symlinks
  vcheck "serial ports"      verify_serial_access
  vcheck "ser2net"           verify_ser2net
  [[ -x "$NIRI_BIN" ]] && vcheck "niri desktop" verify_niri
  vcheck "shell lint"        verify_shell_lint
  vcheck "dpkg state"        verify_dpkg_state

  rm -rf "$VERIFY_TMP"; VERIFY_TMP=""
}

cmd_setup() {
  echo
  banner

  # Everything after this needs sudo, so without it there is nothing to continue
  # into: each later step would fail in turn and bury the one real cause.
  install_apt_packages || {
    echo
    echo -e "\r\033[K  ${RED}${BOLD}Stopped.${RESET} ${SUBTEXT}sudo is needed; run ./install.sh --setup from a terminal.${RESET}"
    echo
    exit 1
  }

  # One header per group, the tools beneath it — each installer names itself in
  # its own status lines. Order is load-bearing: Rust before tree-sitter (which
  # builds with cargo on old glibc), Oh My Zsh before the symlinks (it deletes
  # the default ~/.zshrc), and everything after apt (curl, unzip).
  section "Command-line tools"
  install_bat
  install_delta
  install_difftastic
  install_fzf
  install_eza
  install_ripgrep
  install_fd
  install_zoxide
  install_direnv
  install_just
  install_dust
  install_duf
  install_yazi
  install_btop
  install_jq
  install_lazygit
  install_glab
  install_gh
  install_bw

  section "Python"
  install_uv

  section "Build toolchain"
  install_cmake
  install_ninja
  install_uv_tool meson "Meson"
  install_arm_gcc
  install_llvm_clang_tools
  install_clang_compiler
  ensure_clang_libstdcxx
  install_rust

  section "Editor tooling"
  install_tree_sitter_cli
  install_uv_tool ruff "Ruff"
  install_uv_tool basedpyright "basedpyright"
  install_uv_tool shellcheck-py "shellcheck"
  install_stylua
  install_lua_language_server
  remove_mason

  section "Shell and fonts"
  install_omz
  install_omz_plugins
  install_fonts

  section "Applications"
  install_kitty
  install_neovim
  install_vscode
  install_claude

  section "Serial ports"
  install_serial_access
  install_ser2net

  # Opt-in (--niri); once installed, kept at the versions file's pins.
  if [[ -x "$NIRI_BIN" ]]; then
    section "niri desktop"
    install_niri_desktop
  fi

  # Nothing past this point needs sudo — stop refreshing the credential so the
  # background loop can't contend with the interactive [y/N] prompts below for
  # the controlling terminal.
  if [[ -n "$SUDO_KEEPALIVE_PID" ]]; then
    kill "$SUDO_KEEPALIVE_PID" 2>/dev/null
    wait "$SUDO_KEEPALIVE_PID" 2>/dev/null
  fi

  section "Dotfile symlinks"
  local section_l src dst
  for entry in "${LINKS[@]}"; do
    link_parts "$entry" section_l src dst
    make_link "$src" "$dst"
  done
  merge_claude_settings
  fix_ssh_modes
  ensure_login_path

  configure_theme
  configure_identity
  set_default_terminal
  set_default_shell

  # Last, so it validates the finished system rather than a half-built one.
  verify_install

  echo
  if (( FAIL_COUNT > 0 )); then
    echo -e "\r\033[K  ${RED}${BOLD}Done with ${FAIL_COUNT} error(s).${RESET} ${SUBTEXT}See the ✗ lines above; re-run ./install.sh --setup to retry.${RESET}"
  elif [[ "$NEED_RESTART" == true ]]; then
    echo -e "\r\033[K  ${MAUVE}${BOLD}Done!${RESET} ${YELLOW}Log out and back in, then open Kitty: the new login shell (Zsh) and group memberships start with the next session.${RESET}"
  else
    echo -e "\r\033[K  ${MAUVE}${BOLD}Done!${RESET} ${TEXT}Everything is set up.${RESET}"
  fi
  echo
}

# Same checks --setup ends with, on their own, so the system can be re-checked
# without sitting through a full run (nothing here needs sudo either).
cmd_verify() {
  echo
  banner

  verify_install

  echo
  if (( FAIL_COUNT > 0 )); then
    echo -e "\r\033[K  ${RED}${BOLD}${FAIL_COUNT} check(s) failed.${RESET} ${SUBTEXT}See the ✗ lines above.${RESET}"
  else
    echo -e "\r\033[K  ${MAUVE}${BOLD}All good!${RESET} ${TEXT}Everything checks out.${RESET}"
  fi
  echo
}

# The interactive steps --setup ends with, each runnable on its own so changing
# the theme or the git profile doesn't mean sitting through a full bootstrap.
cmd_theme() {
  echo
  banner

  configure_theme

  echo
  echo -e "\r\033[K  ${MAUVE}${BOLD}Done!${RESET} ${TEXT}Open a new terminal (or run exec zsh) to pick up the prompt and shell colors.${RESET}"
  echo
}

cmd_identity() {
  echo
  banner

  configure_identity

  echo
  echo -e "\r\033[K  ${MAUVE}${BOLD}Done!${RESET} ${TEXT}Open a new terminal (or run exec zsh) to load the profile.${RESET}"
  echo
}

cmd_link() {
  echo
  banner

  local section_l src dst last_section=""
  for entry in "${LINKS[@]}"; do
    link_parts "$entry" section_l src dst
    if [[ "$section_l" != "$last_section" ]]; then
      section "$section_l"
      last_section="$section_l"
    fi
    make_link "$src" "$dst"
  done
  merge_claude_settings
  fix_ssh_modes
  ensure_login_path

  configure_theme

  echo
  echo -e "\r\033[K  ${MAUVE}${BOLD}Done!${RESET} ${TEXT}Restart your shell to apply changes.${RESET}"
  echo
}

cmd_clean() {
  echo
  banner

  section "Removing symlinks"
  local section_l src dst
  for entry in "${LINKS[@]}" "${NIRI_LINKS[@]}"; do
    link_parts "$entry" section_l src dst
    remove_link "$src" "$dst"
  done

  # Per-machine theme pointers (created by configure_theme, not in LINKS)
  local pointers=(
    "$HOME/.config/kitty/current-theme.conf:$DOTFILES/.config/kitty/"
    "$HOME/.config/bat/config:$DOTFILES/.config/bat/"
    "$HOME/.config/fzf/active.sh:$DOTFILES/.config/fzf/"
    "$HOME/.config/eza/theme.yml:$DOTFILES/.config/eza/"
    "$HOME/.config/btop/themes/active.theme:$DOTFILES/.config/btop/themes/"
    "$HOME/.config/zsh-syntax-highlighting/active.zsh:$DOTFILES/.config/zsh-syntax-highlighting/"
    "$HOME/.config/lazygit/active-theme.yml:$DOTFILES/.config/lazygit/"
    "$HOME/.config/p10k/active.zsh:$DOTFILES/.config/p10k/"
    "$HOME/.config/yazi/theme.toml:$DOTFILES/.config/yazi/"
    "$HOME/.config/niri/theme.kdl:$DOTFILES/.config/niri/"
    "$HOME/.config/waybar/theme.css:$DOTFILES/.config/waybar/"
    "$HOME/.config/fuzzel/fuzzel.ini:$DOTFILES/.config/fuzzel/"
    "$HOME/.config/mako/config:$DOTFILES/.config/mako/"
    "$HOME/.config/swaylock/config:$DOTFILES/.config/swaylock/"
    "$HOME/.config/niri/wallpaper.svg:$DOTFILES/.config/niri/wallpapers/"
  )
  for entry in "${pointers[@]}"; do
    local link="${entry%%:*}" prefix="${entry#*:}"
    if [[ -L "$link" && "$(readlink "$link")" == "$prefix"* ]]; then
      rm "$link" && log_unlinked "${link#"$HOME/"}"
    fi
  done

  echo
  echo -e "\r\033[K  ${MAUVE}${BOLD}Done!${RESET} ${TEXT}All dotfile symlinks removed.${RESET}"
  echo
}

# Chooses which LLVM version the toolchain runs, and records it so --setup keeps
# honouring it instead of quietly upgrading back to latest on the next run.
cmd_llvm() {
  local spec="${1:-}"
  echo
  banner

  local pin; pin=$(llvm_pin)

  # No argument is a read-only status report — deliberately no sudo, so asking
  # "what am I on?" never prompts for a password.
  if [[ -z "$spec" ]]; then
    section "LLVM/Clang tools"
    local active; active=$(llvm_installed_version)
    if [[ -n "$pin" ]]; then
      log_ok "pinned to $pin ($(llvm_pin_source))"
    else
      log_skip "tracking latest — --setup upgrades to the newest release"
    fi
    # Sized behind a spinner: du over a couple of 12GB trees takes several
    # seconds, and a status command that looks hung is worse than a slow one.
    local listing
    run_spin_capture "measuring LLVM trees under /opt..." listing llvm_status_rows "$active"
    if [[ -z "$listing" ]]; then
      log_warn "no LLVM tree under /opt — run ./install.sh --setup"
    else
      local row
      while IFS= read -r row; do
        [[ "$row" == active* ]] && log_ok "${row#active }" || log_skip "${row#ondisk }"
      done <<< "$listing"
    fi
    echo
    return
  fi

  if [[ "$spec" == clean ]]; then
    section "LLVM/Clang tools"
    if [[ -z "$(llvm_installed_version)" ]]; then
      log_error "LLVM/Clang tools" "/opt/llvm does not resolve to a version — refusing to prune"
      echo; return
    fi
    sudo -v || { log_error "LLVM/Clang tools" "sudo required to remove trees under /opt"; echo; return; }
    llvm_report_prune 1
    log_skip "kept $(llvm_installed_version) (active)"
    echo
    return
  fi

  # default drops this machine's override and goes back to the versions file.
  # Nothing is installed here; the next --setup applies it.
  if [[ "$spec" == default ]]; then
    section "LLVM/Clang tools"
    rm -f "$LLVM_PIN_FILE"
    pin=$(llvm_pin)
    log_ok "override removed — ${pin:+pinned to $pin by the }${pin:-tracking latest per the }dotfiles versions file; run ./install.sh --setup to apply"
    echo; return
  fi

  if [[ ! "$spec" =~ ^(latest|[0-9]+(\.[0-9]+){0,2})$ ]]; then
    section "LLVM/Clang tools"
    log_error "LLVM/Clang tools" "unrecognised version '$spec' — expected latest, 18, 18.1, 18.1.8, default, or clean"
    echo; return
  fi

  section "LLVM/Clang tools"
  local want
  run_spin_capture "resolving '$spec'..." want llvm_resolve_version "$spec"
  if [[ ! "$want" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_error "LLVM/Clang tools" "could not resolve '$spec' to a release version"
    echo; return
  fi

  # Prove the release actually exists before touching the pin file. Writing a
  # pin first and failing after would leave every later --setup run trying to
  # install a version that does not exist.
  local asset
  run_spin_capture "checking LLVM $want is published for $ARCH_LLVM..." asset llvm_asset "$want"
  if [[ -z "$asset" ]]; then
    log_error "LLVM/Clang tools" "no Linux $ARCH_LLVM release asset for $want — pin unchanged${pin:+ (still $pin)}"
    echo; return
  fi

  # "latest" is written rather than the file removed, because without the
  # file the versions file's pin applies again.
  mkdir -p "$(dirname "$LLVM_PIN_FILE")"
  if [[ "$spec" == latest ]]; then
    printf 'latest\n' > "$LLVM_PIN_FILE"
    log_ok "tracking latest ($want) on this machine (~/${LLVM_PIN_FILE#"$HOME"/})"
  else
    printf '%s\n' "$want" > "$LLVM_PIN_FILE"
    log_ok "pinned to $want (~/${LLVM_PIN_FILE#"$HOME"/})"
  fi

  local installed; installed=$(llvm_installed_version)
  if [[ "$installed" == "$want" ]]; then
    log_skip "LLVM/Clang tools $want already active"
    echo; return
  fi

  # Prime sudo visibly, before any spinner starts: a password prompt drawn
  # underneath a redrawing spinner line is unreadable. Same reason
  # install_apt_packages primes it up front during --setup.
  sudo -v || { log_error "LLVM/Clang tools" "sudo required to install under /opt"; echo; return; }
  llvm_activate "$want"

  echo
  if (( FAIL_COUNT > 0 )); then
    echo -e "\r\033[K  ${RED}${BOLD}Done with ${FAIL_COUNT} error(s).${RESET} ${SUBTEXT}See the ✗ lines above.${RESET}"
  else
    echo -e "\r\033[K  ${MAUVE}${BOLD}Done!${RESET} ${TEXT}clang, clangd, clang-format, clang-tidy and lld are now $want.${RESET}"
  fi
  echo
}

usage() {
  echo
  banner
  echo
  echo -e "  ${TEXT}${BOLD}Usage:${RESET}"
  echo -e "    ${GREEN}./install.sh${RESET}               ${SUBTEXT}Create dotfile symlinks${RESET}"
  echo -e "    ${GREEN}./install.sh -s, --setup${RESET}   ${SUBTEXT}Full system bootstrap${RESET}"
  echo -e "    ${GREEN}./install.sh -c, --clean${RESET}   ${SUBTEXT}Remove all dotfile symlinks${RESET}"
  echo -e "    ${GREEN}./install.sh -v, --verify${RESET}  ${SUBTEXT}Check the installed toolchain works${RESET}"
  echo -e "    ${GREEN}./install.sh --theme${RESET}       ${SUBTEXT}Pick or re-apply the color theme, nothing else${RESET}"
  echo -e "    ${GREEN}./install.sh --identity${RESET}    ${SUBTEXT}Set your git name and email, pick the personal or work profile, nothing else${RESET}"
  echo -e "    ${GREEN}./install.sh --llvm${RESET}        ${SUBTEXT}Show the LLVM pin, the active version and what's on disk${RESET}"
  echo -e "    ${GREEN}./install.sh --ser2net${RESET}     ${SUBTEXT}Build the newest ser2net and gensio from source, for ports share, nothing else${RESET}"
  echo -e "    ${GREEN}./install.sh --niri${RESET}        ${SUBTEXT}Add the niri tiling session to the login screen (builds niri, xwayland-satellite, Waybar)${RESET}"
  echo -e "    ${GREEN}./install.sh -h, --help${RESET}    ${SUBTEXT}Show this help message${RESET}"
  echo
  echo -e "  ${TEXT}${BOLD}Tool versions:${RESET}"
  echo -e "    ${SUBTEXT}LLVM, the clang compiler, the Arm toolchain, CMake, Ninja, Ruff and the niri desktop are installed at the versions${RESET}"
  echo -e "    ${SUBTEXT}in the repo's versions file, and Powerlevel10k and the zsh plugins at the commits it pins.${RESET}"
  echo -e "    ${SUBTEXT}Override one per machine in ~/.config/dotfiles/versions.${RESET}"
  echo
  echo -e "  ${TEXT}${BOLD}Choosing an LLVM version:${RESET}"
  echo -e "    ${GREEN}./install.sh --llvm 19.1.7${RESET} ${SUBTEXT}Pin this machine to an exact version (also accepts 19 or 19.1 for newest in that series)${RESET}"
  echo -e "    ${GREEN}./install.sh --llvm latest${RESET}  ${SUBTEXT}Track the newest release on this machine${RESET}"
  echo -e "    ${GREEN}./install.sh --llvm default${RESET} ${SUBTEXT}Drop the override and follow the versions file again${RESET}"
  echo -e "    ${GREEN}./install.sh --llvm clean${RESET}   ${SUBTEXT}Drop every inactive LLVM tree under /opt${RESET}"
  echo -e "    ${SUBTEXT}The override is stored in ~/.config/llvm/version and honoured by --setup, so a run${RESET}"
  echo -e "    ${SUBTEXT}can't quietly move you off it. The previous version is kept under /opt, so switching${RESET}"
  echo -e "    ${SUBTEXT}back is a symlink repoint, not a download.${RESET}"
  echo
  echo -e "  ${TEXT}${BOLD}--setup installs:${RESET}"
  echo -e "    ${TEXT}${BOLD}System${RESET}"
  echo -e "      ${SUBTEXT}System update        ${TEXT}git-core PPA, then apt update & upgrade${RESET}"
  echo -e "      ${SUBTEXT}System packages      ${TEXT}build-essential, curl, fonts-symbola, g++, gcc, git, git-lfs, tree, unzip, valgrind, wget, zsh${RESET}"
  echo -e "    ${TEXT}${BOLD}Command-line tools${RESET}"
  echo -e "      ${SUBTEXT}bat                  ${TEXT}syntax-highlighted file viewer${RESET}"
  echo -e "      ${SUBTEXT}delta                ${TEXT}git diff viewer${RESET}"
  echo -e "      ${SUBTEXT}difftastic           ${TEXT}syntax-aware diffs: git dft, and a second diff view in lazygit (latest, GitHub release)${RESET}"
  echo -e "      ${SUBTEXT}fzf                  ${TEXT}fuzzy finder (latest, GitHub release)${RESET}"
  echo -e "      ${SUBTEXT}eza                  ${TEXT}modern ls replacement (latest, GitHub release)${RESET}"
  echo -e "      ${SUBTEXT}ripgrep              ${TEXT}fast recursive search (latest, GitHub release)${RESET}"
  echo -e "      ${SUBTEXT}fd                   ${TEXT}fast find (latest, GitHub release)${RESET}"
  echo -e "      ${SUBTEXT}zoxide               ${TEXT}smarter cd (latest, GitHub release)${RESET}"
  echo -e "      ${SUBTEXT}direnv               ${TEXT}loads a directory's .envrc on cd (latest, GitHub release)${RESET}"
  echo -e "      ${SUBTEXT}just                 ${TEXT}runs a project's recipes from its justfile (latest, GitHub release)${RESET}"
  echo -e "      ${SUBTEXT}dust                 ${TEXT}du with a visual tree (latest, GitHub release)${RESET}"
  echo -e "      ${SUBTEXT}duf                  ${TEXT}df with a readable table (latest, GitHub release)${RESET}"
  echo -e "      ${SUBTEXT}yazi                 ${TEXT}terminal file manager with image previews (latest, GitHub release)${RESET}"
  echo -e "      ${SUBTEXT}btop                 ${TEXT}process/resource monitor (latest, GitHub release)${RESET}"
  echo -e "      ${SUBTEXT}jq                   ${TEXT}JSON processor, required by Claude Code status line (latest, GitHub release)${RESET}"
  echo -e "      ${SUBTEXT}lazygit              ${TEXT}terminal UI for git${RESET}"
  echo -e "      ${SUBTEXT}glab                 ${TEXT}GitLab CLI: merge requests, pipelines, issues (latest, GitLab .deb)${RESET}"
  echo -e "      ${SUBTEXT}gh                   ${TEXT}GitHub CLI: pull requests, actions, issues (latest, GitHub .deb)${RESET}"
  echo -e "      ${SUBTEXT}Bitwarden CLI        ${TEXT}bw, backs the git credential helper for HTTPS remotes (latest, GitHub release)${RESET}"
  echo -e "    ${TEXT}${BOLD}Build toolchain${RESET}"
  echo -e "      ${SUBTEXT}CMake                ${TEXT}build system generator (latest, GitHub release)${RESET}"
  echo -e "      ${SUBTEXT}ninja                ${TEXT}build system, used with cmake (latest, GitHub release)${RESET}"
  echo -e "      ${SUBTEXT}ARM GNU Toolchain    ${TEXT}bare-metal arm-none-eabi-gcc/gdb/etc. (latest, GitLab release)${RESET}"
  echo -e "      ${SUBTEXT}LLVM/Clang tools     ${TEXT}clangd, clang-format, clang-tidy, clang, lld (GitHub release; honours the --llvm pin, else latest; 7-12GB per version)${RESET}"
  echo -e "      ${SUBTEXT}Rust                 ${TEXT}rustc, cargo, rustfmt, clippy (official rustup installer, stable)${RESET}"
  echo -e "    ${TEXT}${BOLD}Python${RESET}"
  echo -e "      ${SUBTEXT}uv                   ${TEXT}Python versions, projects and venvs (standalone installer; replaces pyenv + Poetry)${RESET}"
  echo -e "    ${TEXT}${BOLD}Editor tooling${RESET}"
  echo -e "      ${SUBTEXT}tree-sitter CLI      ${TEXT}compiles nvim-treesitter parsers (latest, GitHub release; built with cargo on glibc < 2.39)${RESET}"
  echo -e "      ${SUBTEXT}Ruff                 ${TEXT}Python linter/formatter (uv tool, on PATH for Neovim and the CLI)${RESET}"
  echo -e "      ${SUBTEXT}basedpyright         ${TEXT}Python type checker (uv tool, on PATH for Neovim and the CLI)${RESET}"
  echo -e "      ${SUBTEXT}StyLua               ${TEXT}Lua formatter (GitHub release, on PATH for Neovim and the CLI)${RESET}"
  echo -e "      ${SUBTEXT}shellcheck           ${TEXT}shell script linter; --verify runs it on install.sh (uv tool)${RESET}"
  echo -e "      ${SUBTEXT}lua-language-server  ${TEXT}Lua language server for Neovim (GitHub release, in ~/.local)${RESET}"
  echo -e "    ${TEXT}${BOLD}Shell and fonts${RESET}"
  echo -e "      ${SUBTEXT}Oh My Zsh            ${TEXT}zsh framework${RESET}"
  echo -e "      ${SUBTEXT}Zsh plugins          ${TEXT}Powerlevel10k, zsh-syntax-highlighting, zsh-autosuggestions, zsh-bat, fzf-tab, fzf-git (pinned commits)${RESET}"
  echo -e "      ${SUBTEXT}Fonts                ${TEXT}FiraCode Nerd Font, Maple Mono NL (italics)${RESET}"
  echo -e "    ${TEXT}${BOLD}Applications${RESET}"
  echo -e "      ${SUBTEXT}Kitty                ${TEXT}GPU-accelerated terminal${RESET}"
  echo -e "      ${SUBTEXT}Neovim               ${TEXT}pinned to v${NVIM_VERSION} (release tarball; nvim-treesitter main needs 0.12+)${RESET}"
  echo -e "      ${SUBTEXT}Visual Studio Code   ${TEXT}Microsoft apt repo${RESET}"
  echo -e "      ${SUBTEXT}Claude Code          ${TEXT}Anthropic CLI (native installer, auto-updates)${RESET}"
  echo -e "    ${TEXT}${BOLD}Serial ports${RESET}"
  echo -e "      ${SUBTEXT}dialout group        ${TEXT}open USB-serial adapters without sudo or chmod${RESET}"
  echo -e "      ${SUBTEXT}FTDI latency rule    ${TEXT}udev sets every FTDI port's latency timer to 1 ms on plug-in${RESET}"
  echo -e "      ${SUBTEXT}ports                ${TEXT}list USB serial ports, -w to watch plug/unplug, share/unshare one on the network${RESET}"
  echo -e "      ${SUBTEXT}ser2net              ${TEXT}newest ser2net + gensio built from source into /usr/local, for ports share${RESET}"
  echo -e "    ${TEXT}${BOLD}Configuration${RESET}"
  echo -e "      ${SUBTEXT}Dotfile symlinks${RESET}"
  echo -e "      ${SUBTEXT}Theme                ${TEXT}pick Catppuccin (frappe/macchiato/mocha), Gruvbox Dark, or Dracula — kitty + bat + nvim + fzf + eza + tab bar + btop + zsh-syntax-highlighting + lazygit + delta + Powerlevel10k + yazi, and the niri session's bar, launcher, notifications and lock screen${RESET}"
  echo -e "      ${SUBTEXT}Default terminal     ${TEXT}Kitty via gsettings${RESET}"
  echo -e "      ${SUBTEXT}Default shell        ${TEXT}Zsh via chsh${RESET}"
  echo -e "      ${SUBTEXT}Verification         ${TEXT}compiles/runs C + C++, cross-compiles for bare-metal Arm, drives clangd, builds with cmake+ninja${RESET}"
  echo
  echo -e "  ${TEXT}${BOLD}Notes:${RESET}"
  echo -e "    ${SUBTEXT}Safe to run from bash — installs Zsh and sets it as default shell.${RESET}"
  echo -e "    ${SUBTEXT}Each step is skipped if already up to date.${RESET}"
  echo -e "    ${SUBTEXT}-c only removes symlinks pointing to this repo — it never touches /opt or apt.${RESET}"
  echo -e "    ${SUBTEXT}--llvm with no argument is read-only and never asks for sudo.${RESET}"
  echo -e "    ${SUBTEXT}Exits non-zero if any step failed — see the ✗ lines and end-of-run summary.${RESET}"
  echo
}

# ── Entry point ────────────────────────────────────────────────────────────────

case "${1}" in
  -s | --setup)  cmd_setup ;;
  --link | "")   cmd_link ;;
  -c | --clean)  cmd_clean ;;
  -v | --verify) cmd_verify ;;
  --theme)       cmd_theme ;;
  --identity)    cmd_identity ;;
  --llvm)        cmd_llvm "${2:-}" ;;
  --ser2net)     cmd_ser2net ;;
  --niri)        cmd_niri ;;
  -h | --help)   usage ;;
  *)
    echo -e "\n  ${RED}Unknown option:${RESET} $1"
    usage; exit 1 ;;
esac

# Non-zero exit whenever any step logged an error, so scripted/cron use of
# --setup can actually detect a partial run instead of always seeing success.
exit $(( FAIL_COUNT > 0 ? 1 : 0 ))
