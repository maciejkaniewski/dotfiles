---
name: handoff
description: Write or update the hand-off a fresh session needs to continue the work in this repo, as one untracked HANDOFF.md at the repo root, and pick one up. Use when asked for a handoff, a "where we stopped" note, something to continue from tomorrow or in a new session, or to read and continue from HANDOFF.md.
---

# Handoff

One file per repo, `HANDOFF.md` at the git root. It is rewritten each time, never appended to and
never committed.

## Writing it

1. Put it at `$(git rev-parse --show-toplevel)/HANDOFF.md`.
2. Keep it out of `git status` without touching the shared `.gitignore`: add `HANDOFF.md` to
   `$(git rev-parse --git-common-dir)/info/exclude` if it is not listed there yet.
3. Rewrite the whole file. The first line is
   `# <repo> handoff, updated <YYYY-MM-DD> (untracked, never commit it)`. Then these sections,
   each only when it has something in it:
   - **Where things stand**: tickets and their states, branches and what is pushed, pipelines,
     releases, and what is waiting on whom.
   - **Decided**: what was settled and why, a line each, so the next session does not reopen it.
   - **Next**: the first concrete step, then the rest in order.
   - **Loose ends**: uncommitted files, local-only branches, and what to delete when the work lands.
4. At most about 80 lines. Hashes, numbers and links, not the story of the session.
5. Keep a single pointer in the project's auto memory, "read `HANDOFF.md` at the repo root first",
   and nothing about the state itself. Remove the pointer and the file once the work they cover
   has landed.

## Picking it up

Read `HANDOFF.md`, then check its claims against `git status`, `git log` and the ticket states,
which may have moved since it was written. Say what differs, then start from **Next**.
