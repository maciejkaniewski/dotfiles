#!/usr/bin/env bash
# PostToolUse hook: after Claude writes a file, tell every running Neovim to
# re-compare its buffers against disk (`:checktime`, which is what makes
# 'autoread' actually fire).
#
# Without this, an open buffer keeps stale content until nvim happens to regain
# focus — and auto-save.nvim can then write that stale buffer back over the edit.
# Note this only reloads buffers with no unsaved changes; 'autoread' refuses to
# discard your own edits, so a genuine conflict still has to be resolved by hand.
#
# Best effort by design: no running nvim, no socket, or a busy instance all exit
# quietly rather than interrupting the tool call.

set -uo pipefail

command -v nvim >/dev/null 2>&1 || exit 0

runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
[[ -d "$runtime_dir" ]] || exit 0

for sock in "$runtime_dir"/nvim.*; do
    [[ -S "$sock" ]] || continue
    # timeout: a modal prompt inside nvim (unsaved conflict) would block the RPC
    timeout 2 nvim --server "$sock" --remote-expr 'execute("checktime")' \
        >/dev/null 2>&1 || true
done

exit 0
