# direnv — export the current directory's .envrc before the instant prompt so its
# "direnv: loading" output can't trip the instant-prompt warning (the pattern
# from Powerlevel10k's FAQ); the hook that keeps it going on cd comes after.
(( ! ${+commands[direnv]} )) || emulate zsh -c "$(direnv export zsh)"

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.oh-my-zsh"
DISABLE_AUTO_TITLE="true"

ZSH_THEME="powerlevel10k/powerlevel10k"

# Order matters: zsh-syntax-highlighting must be sourced last (after every widget
# is defined), and zsh-autosuggestions just before it. fzf defines its ZLE widgets
# earlier so the highlighter can wrap them. fzf-tab has to load after compinit
# (Oh My Zsh runs it before any plugin) but before those two widget wrappers.
plugins=(git zsh-bat fzf fzf-tab zsh-autosuggestions zsh-syntax-highlighting)

# Catppuccin's zsh-syntax-highlighting colors must be sourced BEFORE the
# plugin activates (set by install.sh; per the upstream port's own README).
[[ -f ~/.config/zsh-syntax-highlighting/active.zsh ]] && source ~/.config/zsh-syntax-highlighting/active.zsh

source $ZSH/oh-my-zsh.sh

# History — after oh-my-zsh.sh, which sets its own defaults and would otherwise
# overwrite these. Oh My Zsh already gives us hist_ignore_dups,
# hist_ignore_space, extended_history and hist_verify; what it leaves is:
#   SAVEHIST     defaults to 10000 while HISTSIZE is 50000, so four fifths of
#                the in-memory history is discarded at exit. Match them.
#   ALL_DUPS     hist_ignore_dups only drops *consecutive* repeats, so a command
#                alternated with another still accumulates one copy per run.
#   REDUCE_BLANKS strips the stray whitespace that makes those near-duplicates.
#   SHARE_HISTORY Oh My Zsh turns it on, which feeds every command typed in one
#                window into the Up-arrow history of all the others. Off, each
#                window recalls its own commands (plus whatever was saved when it
#                started); INC_APPEND_HISTORY still writes every command to the
#                file as it runs, so new windows see all of them and none are lost.
SAVEHIST=$HISTSIZE
setopt HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS INC_APPEND_HISTORY
unsetopt SHARE_HISTORY

# Keep lines whose first word can't run out of history. Text pasted while a
# command is still running waits in the terminal until it exits, then zsh
# reads it line by line, so every log line or table row was saved as a
# "command"; typos (gti, lzaygit) went the same way. A skipped line can still
# be recalled with Up until the next one runs. Only a plain first word is
# judged: one with quotes, $, ~, /, globs, a # comment or other syntax is kept.
_history_skip_unrunnable() {
  local -a words=(${(z)1})
  while [[ $words[1] == [[:alpha:]_][[:alnum:]_]#=* ]]; do shift words; done
  [[ $words[2] == '()' ]] && return 0
  local first=${(Q)words[1]}
  [[ -z $first || $first == *[\$~/\(\{\[\"\'\\\!\*\?=\<\>\|\&\;\#\`]* ]] && return 0
  whence -- "$first" &>/dev/null || [[ -d $first ]] || return 1
}
autoload -Uz add-zsh-hook
add-zsh-hook zshaddhistory _history_skip_unrunnable

export EDITOR="nvim"

# Dedup PATH so re-sourcing ~/.zshrc doesn't accumulate duplicate entries.
typeset -U path PATH
# First, as Ubuntu's ~/.profile would put it. Once zsh is the login shell the
# desktop session no longer reads ~/.profile, and with ~/.local/bin last apt's
# copies (meson, say) won over the newer uv-installed ones.
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.local/kitty.app/bin:$PATH"
# No entry needed for the ARM cross-toolchain: install.sh symlinks every
# arm-none-eabi-* tool into /usr/local/bin, which is already on PATH. A prepend
# here would only be visible to interactive shells — not to cron, systemd, CI,
# or GUI-launched editors — so the symlinks are what make it reliably findable.

# clang-sys (bindgen, and any Rust build that parses C headers) loads libclang
# on its own and doesn't look in /opt/llvm. Point it there only while the clang
# on PATH comes from that tree, so the library always matches the driver.
[[ ${commands[clang]:A} == /opt/* && -e /opt/llvm/lib/libclang.so ]] && export LIBCLANG_PATH=/opt/llvm/lib

[[ -f /etc/zsh_command_not_found ]] && source /etc/zsh_command_not_found

# lazygit theme — merges the base config with the active Catppuccin flavor's
# theme file (set by install.sh) instead of a single hardcoded theme.
export LG_CONFIG_FILE="$HOME/.config/lazygit/config.yml,$HOME/.config/lazygit/active-theme.yml"
# Machine-local lazygit settings (e.g. `services:` for a self-hosted GitLab),
# loaded last. Append here rather than reassigning LG_CONFIG_FILE in
# ~/.zshrc.local, which would drop the theme file.
[[ -f ~/.config/lazygit/config.local.yml ]] && LG_CONFIG_FILE+=",$HOME/.config/lazygit/config.local.yml"

# fzf colors — sourced from the active Catppuccin flavor (set by install.sh)
[[ -f ~/.config/fzf/active.sh ]] && source ~/.config/fzf/active.sh

# fzf previews. Deliberately in FZF_CTRL_T_OPTS / FZF_ALT_C_OPTS rather than
# FZF_DEFAULT_OPTS: the theme file above *assigns* FZF_DEFAULT_OPTS rather than
# appending to it, so anything put there would be dropped the next time the
# theme picker re-sourced it. These two variables are additive and theme-safe.
if command -v bat &>/dev/null; then
  # --line-range caps the work on huge generated files (firmware .map, .su).
  export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:500 {}' --preview-window=right,60%,border-left"
fi
if command -v eza &>/dev/null; then
  export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --icons=always --color=always {}' --preview-window=right,60%,border-left"
fi

# fzf backend — use fd (fast, .gitignore-aware, includes hidden files) for
# Ctrl-T file search and Alt-C directory jump. Falls back to fdfind's name on
# Debian if the `fd` symlink is unavailable; if neither exists, fzf uses find.
FD_BIN=$(command -v fd || command -v fdfind) 2>/dev/null
if [[ -n "$FD_BIN" ]]; then
  export FZF_DEFAULT_COMMAND="$FD_BIN --type f --hidden --follow --exclude .git"
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND="$FD_BIN --type d --hidden --follow --exclude .git"
fi

# fzf-tab — Tab opens completions in fzf. `menu no` hands the candidates to
# fzf-tab instead of zsh's own menu; it has to use Oh My Zsh's exact pattern to
# replace its `menu select`, since a plain ':completion:*' is less specific and
# loses. The descriptions format turns on fzf-tab's group headers, and
# use-fzf-default-opts picks up the theme colours above (upstream warns some
# flags there break it, but the theme files only set --color).
zstyle ':completion:*:*:*:*:*' menu no
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':fzf-tab:*' use-fzf-default-opts yes
command -v eza &>/dev/null && zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --icons=always --color=always $realpath'
# Host completion (ssh, scp, s) is built here instead of by zsh, which left out
# IP addresses (most machines on a local network have no name to complete
# instead), read known_hosts once per shell (a machine first logged in to after
# that never showed up) and offered a Host alias from ~/.ssh/config only when
# nothing else matched (an empty Tab never listed it). This list has getent's
# names and addresses, known_hosts and every Host alias in ~/.ssh/config and
# the files it includes, and it is read again on every Tab.
_completion_hosts() {
  local -a files=(~/.ssh/config) known
  local file key rest word
  reply=(${=${(f)"$(getent hosts)"}})
  # known_hosts: hostnames before the key, comma-separated; [host]:port keeps
  # the host. Hashed entries (|1|…) and wildcards have no name to offer.
  [[ -r ~/.ssh/known_hosts ]] && known=(${(f)"$(<~/.ssh/known_hosts)"})
  known=(${(s:,:)${(j:,:)known%%[ |#]*}})
  for word in $known; do
    [[ $word == \[*\]:* ]] && word=${${word#\[}%%\]*}
    [[ $word == *[*?]* ]] || reply+=($word)
  done
  # Include paths are relative to ~/.ssh and may be globs.
  while (( $#files )); do
    file=$files[1]; shift files
    [[ -r $file ]] || continue
    while read -r key rest; do
      case ${(L)key} in
        include)
          for word in ${(z)rest}; do
            [[ $word == [/~]* ]] || word=~/.ssh/$word
            files+=(${~word}(N))
          done ;;
        host) reply+=(${${(z)rest}:#*[*?!]*}) ;;
      esac
    done < $file
  done
  reply=(${(u)reply:#})
}
zstyle -e ':completion:*:hosts' hosts '_completion_hosts'

# fzf-git — Ctrl+G then Ctrl+F/B/H/T/S/R puts git files, branches, commit
# hashes, tags, stashes or remotes at the cursor; Ctrl+G ? lists them all.
[[ -f $ZSH_CUSTOM/plugins/fzf-git/fzf-git.sh ]] && source $ZSH_CUSTOM/plugins/fzf-git/fzf-git.sh
# Ctrl+G on its own is zsh's send-break, so pausing after it for longer than
# KEYTIMEOUT threw the line away instead of waiting for the second key. With
# it unbound zsh waits as long as needed; Ctrl+C still discards a line.
bindkey -r '^G'

# gweb — open this repo's origin in the browser (also Ctrl+G O). GitHub and the
# company GitLab both serve a repo at https://<host>/<path>, so rewriting the
# remote URL is enough; no gh/glab login needed. An ssh:// port is the ssh
# daemon's, not the web server's, so it is dropped.
gweb() {
  local url
  url=$(git remote get-url origin 2>/dev/null) || { print -u2 "gweb: no origin remote here"; return 1 }
  url=${url%.git}
  case $url in
    http*) ;;
    ssh://*) url=${url#ssh://}; url=${url#*@}; url=https://${url/:<->\//\/} ;;
    *@*:*) url=${url#*@}; url=https://${url/:/\/} ;;
  esac
  print -r -- "$url"
  xdg-open "$url" &>/dev/null &!
}
_gweb_widget() { zle -I; gweb }
zle -N _gweb_widget
bindkey '^Go' _gweb_widget
bindkey '^G^O' _gweb_widget

# Bitwarden CLI — git asks it for HTTPS credentials through
# .local/bin/git-credential-bw (see .gitconfig). `bwu` unlocks the vault for
# this shell, `bwl` locks it again.
#
# BW_SESSION is the vault's decryption key. It is only ever exported into the
# shell you unlocked in (and whatever that shell starts: git, lazygit, nvim);
# it is never written to a file, so it dies with the shell. Keep it that way:
# no `bw unlock <password>` (lands in history and `ps`), and nothing exporting
# BW_SESSION from ~/.zshrc.local.
bwu() {
  command -v bw &>/dev/null || { print -u2 "bwu: bw is not installed (./install.sh -s)"; return 1 }
  local session
  # A never-logged-in CLI has to `login` (which also unlocks); afterwards
  # `unlock` is enough. --raw prints just the key, so it can be captured.
  case $(bw status 2>/dev/null | jq -r .status 2>/dev/null) in
    unauthenticated) session=$(bw login --raw) ;;
    *)               session=$(bw unlock --raw) ;;
  esac
  [[ -n $session ]] || return 1
  export BW_SESSION=$session
  # The CLI works from a local copy of the vault; without a sync, items added
  # in the app or browser since the last one are invisible to it.
  bw sync --quiet && print "Vault unlocked and synced for this shell — \`bwl\` locks it again."
}
bwl() {
  command -v bw &>/dev/null && bw lock &>/dev/null
  unset BW_SESSION
  print "Vault locked."
}

# bwcp <host> — copy the git token for <host> to the clipboard, for pasting at
# the Password: prompt of a machine that has none of these dotfiles (a server
# you reached over ssh). The token never reaches the screen or shell history,
# and the clipboard is overwritten after 30s.
bwcp() {
  [[ -n $1 ]] || { print -u2 "usage: bwcp <host>   (copies the password of the item \"git: <host>\")"; return 1 }
  [[ -n $BW_SESSION ]] || { print -u2 "bwcp: vault is locked — run bwu"; return 1 }
  local copy
  if command -v kitten &>/dev/null && [[ -n $KITTY_WINDOW_ID ]]; then copy="kitten clipboard"
  elif command -v wl-copy &>/dev/null; then copy="wl-copy"
  elif command -v xclip &>/dev/null; then copy="xclip -selection clipboard"
  else print -u2 "bwcp: no clipboard tool (needs kitty's kitten, wl-copy or xclip)"; return 1; fi
  local pw; pw=$(bw get password "git: $1") || return 1
  printf %s "$pw" | ${=copy} || return 1
  unset pw
  # Overwritten, not just left: a pasted-over clipboard history entry is the
  # best a plain clipboard can do.
  ( sleep 30; printf ' ' | ${=copy} ) &>/dev/null &!
  print "Token for $1 copied; clipboard is overwritten in 30s."
}

# zoxide — smarter cd (`z <partial-dir>` jumps, `zi` fuzzy-picks)
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"
# zoxide fsyncs its database on every directory change, and the prompt waited
# for it. While something writes heavily (a DSView capture) that took long
# enough to notice. Record the visit in the background instead; two cds within
# a few ms can race, and then one visit simply isn't counted.
(( $+functions[__zoxide_hook] )) && __zoxide_hook() { \command zoxide add -- "$(__zoxide_pwd)" &! }

# y — yazi, and the shell lands in whatever directory it was quit in (q;
# Q quits without moving). A program can't change its parent shell's
# directory, so yazi writes it to a file and this wrapper cds there.
y() {
  local tmp cwd
  tmp=$(mktemp -t yazi-cwd.XXXXXX)
  command yazi "$@" --cwd-file="$tmp"
  IFS= read -r -d '' cwd < "$tmp"
  [[ -n $cwd && $cwd != $PWD ]] && builtin cd -- "$cwd"
  rm -f -- "$tmp"
}

# direnv — the hook that loads and unloads a directory's .envrc as you cd
(( ! ${+commands[direnv]} )) || emulate zsh -c "$(direnv hook zsh)"

# eza — modern ls (theme from ~/.config/eza/theme.yml, set per Catppuccin flavor)
if command -v eza &>/dev/null; then
  alias ls='eza --group-directories-first --icons=auto'
  alias ll='eza -lah --group-directories-first --icons=auto --git'
  alias la='eza -a  --group-directories-first --icons=auto'
  alias lt='eza --tree --level=2 --icons=auto'
fi

# uv — shell completion, plus what uv's own completion can't know: after
# `uv run`, Tab offers the project's commands from [project.scripts] in the
# nearest pyproject.toml, and after one of those, its --flags as listed by its
# --help. Flags are only read for those commands: --help is safe to run for a
# typer tool, but an arbitrary script might ignore it and just run.
# pyproject.toml is read by zsh itself because tomllib needs Python 3.11.
if (( $+commands[uv] )); then
  eval "$(uv generate-shell-completion zsh)"

  # Names under [project.scripts] in the nearest pyproject.toml, into $reply.
  _uv_project_scripts() {
    local dir=$PWD line in=0
    while [[ $dir != / && ! -f $dir/pyproject.toml ]]; do dir=${dir:h}; done
    [[ -f $dir/pyproject.toml ]] || return 1
    reply=()
    while IFS= read -r line; do
      if [[ $line =~ '^[[:space:]]*\[' ]]; then
        [[ $line =~ '^[[:space:]]*\[project\.scripts\]' ]] && in=1 || in=0
      elif (( in )) && [[ $line =~ '^[[:space:]]*"?([A-Za-z0-9_.-]+)"?[[:space:]]*=' ]]; then
        reply+=($match[1])
      fi
    done < $dir/pyproject.toml
    (( $#reply ))
  }

  _uv_with_project_scripts() {
    local -a reply flags seen
    local line
    if [[ $words[2] == run ]] && _uv_project_scripts; then
      if (( CURRENT == 3 )); then
        _describe -t project-commands 'project commands' reply
      elif (( CURRENT > 3 )) && [[ $words[CURRENT] == -* ]] && (( $reply[(Ie)$words[3]] )); then
        for line in ${(f)"$(COLUMNS=200 uv run --quiet $words[3] --help 2>/dev/null)"}; do
          [[ $line =~ '^[[:space:]]*(│|[|])[[:space:]]*(--[A-Za-z0-9][A-Za-z0-9_-]*)[[:space:]]+(.*[^[:space:]])[[:space:]]*(│|[|])[[:space:]]*$' ]] || continue
          (( $seen[(Ie)$match[2]] )) && continue
          seen+=($match[2]); flags+=("$match[2]:$match[3]")
        done
        (( $#flags )) && { _describe -t flags "$words[3] options" flags; return }
      fi
    fi
    _uv "$@"
  }
  compdef _uv_with_project_scripts uv
fi

# cpwd — copy the current directory to the clipboard, without a trailing newline
command -v kitten &>/dev/null && alias cpwd='print -rn -- $PWD | kitten clipboard'

# s — ssh through kitty's ssh kitten (shell integration and `kitten transfer`
# on the remote). Only inside kitty; `ssh` itself stays the plain client. A
# function completed as ssh, not an alias: an alias completes through kitten's
# own completer, which prints an error for every Tab that matches nothing,
# because it can't handle the r:|/l:| matchers in Oh My Zsh's matcher-list.
if [[ -n $KITTY_WINDOW_ID ]]; then
  s() { kitten ssh "$@" }
  compdef s=ssh
fi

# cbr — copy the current git branch name to the clipboard, and print it
if command -v kitten &>/dev/null; then
  cbr() {
    local branch
    branch=$(git branch --show-current 2>/dev/null)
    [[ -n $branch ]] || { print -u2 "cbr: not on a branch here"; return 1 }
    print -rn -- "$branch" | kitten clipboard || return
    print -r -- "$branch"
  }
fi

# ksclean — delete saved kitty sessions, the files F3 writes. With no argument
# it opens fzf to pick which (Tab marks several); --all deletes every one. Asks
# before deleting either way.
ksclean() {
  local dir=$HOME/.local/share/kitty/sessions
  local -a picked
  if [[ $1 == --all ]]; then
    picked=($dir/*.kitty-session(N:t:r))
  else
    picked=(${(f)"$(print -rl -- $dir/*.kitty-session(N:t:r) | fzf --multi --prompt='delete session> ' --preview "bat --plain --color=always $dir/{}.kitty-session")"})
  fi
  (( $#picked )) || { print "ksclean: nothing to delete"; return 0 }
  print -rl -- $picked
  read -q "?Delete $#picked session(s)? [y/N] " || { print; return 1 }
  print
  local name
  for name in $picked; do rm -f -- "$dir/$name.kitty-session"; done
}

# Force Zed onto XWayland instead of native Wayland — fullscreen (F11) under
# native Wayland uses Mutter's direct scanout, which bypasses the compositor
# and kills blur-my-shell/theme blur. XWayland windows stay composited.
if command -v zed &>/dev/null; then
  zed-x11() {
    WAYLAND_DISPLAY='' zed "$@"
  }
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Powerlevel10k segment colors — follow the active theme picker (set by
# install.sh), sourced after ~/.p10k.zsh so it only overrides colors, not
# layout/icons/segment order.
[[ -f ~/.config/p10k/active.zsh ]] && source ~/.config/p10k/active.zsh

# Machine-specific overrides (personal or work) — not tracked in dotfiles
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
