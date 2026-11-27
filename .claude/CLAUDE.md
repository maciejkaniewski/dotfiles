# Personal instructions (all projects)

How I work, wherever I work. I build embedded firmware, bench tooling and the desktop tools around
them.
Hard limits are enforced in `~/.claude/settings.json` (deny/ask rules), not here. On a work
machine, work-only rules load from `~/.claude/rules/work/`; team conventions come from the team's
skills and from each repo's own CLAUDE.md and `.claude/`.

## When I correct you

Put the rule where it will be loaded next time, and say where you put it:

- Holds in every repo, wherever I work → propose an edit to this file. It lives in my **public**
  dotfiles (`~/dotfiles/.claude/CLAUDE.md`), so nothing in it may name my employer.
- Holds in every work repo and names a product, host, colleague or internal tool → the work rules
  in `~/.claude/rules/work/` (a private repo).
- A team convention (README shape, commits, issue writing, CI) → the team skill that covers it,
  shown as a diff before any commit.
- A hard "never" → a deny/ask rule in `~/.claude/settings.json`.
- Only a fact about this one repo → project memory, or the repo's own `.claude/` if everyone who
  works in it needs it.

Never save the same rule in two places; if it moves up, delete the lower copy.

## How I like work done

- Smallest thing that does the job. Built-in option before a plugin, one panel before three,
  flat code before a layer. If I say "bloat", cut, don't defend.
- Comments are short and carry only a *why*.
- Before saying "ready, try it", test in the real entry point and environment, and list what could
  only be checked on hardware or in my session as **untested**.
- For bulk wording changes (tooltips, log lines, READMEs), show a before/after table and wait. For
  visual changes, publish a private review page of real-window before/after renders, and wait.
- A device tool is one command named after the project, a TUI with no flags and headless with
  flags. API verbs as pairs (`output_on()` / `output_off()`), not a boolean argument.

## A yes covers one action

A yes counts only for the action it answers. A yes to a plan, an answer to a different question,
or an approved prompt for an earlier step is not a yes to commit, merge, push, tag, post or change
a status. Ask for each, with the final command or text, right before it runs.

## Git

- Stage explicit paths and check every `??` in `git status`; bench dumps, backups, logs, plans and
  handoffs are mine and never committed.
- Commit when I say so. Push only when I say so, one push per command, written in full
  (`git -C <abs path> push ...`, no command held in a variable), never dependent pushes in parallel.
- Never merge without my explicit yes. Merges are local `git merge --no-ff`; never open an MR in my
  own repos. In a colleague's repo, open an MR only when asked and never merge it.
- Push a new tag right after creating it (`fetch.pruneTags=true` deletes unpushed tags on
  `fetch --prune`). Never move a pushed release tag; give me a `!` command if it must move.
- `submodule.recurse=true` is set, so after a merge or switch that moves a submodule, run
  `git submodule update` and check `submodule status` shows no `+`.
- Before a merge or tag, run the CI gate exactly as `.gitlab-ci.yml` does, not a narrowed variant.
- Before handing a branch over, remove (or `git switch --detach`) the worktree holding it, or I
  can't check it out in my clone.

## Hardware and the bench

- Never flash a device yourself; hand me the exact command.
- One process per serial port. Check `fuser -v /dev/ttyUSB*` first, I may have a GUI on it. Kill
  only what you started, by PID (never `pkill -f` on a pattern that matches your own shell).
- Equipment that isn't mine (lab PSUs etc.) is read-only unless I approve the write. Restore
  every setting you touched.
- Bench/test tools take CLI flags only (no env vars), have `--help`, and echo the full resolved
  command at the top of their report.
- For protocol traffic use the project's own tools. Don't suggest tio.

## Writing

- No colon leading into the rest of a sentence in anything people read, including READMEs, docs,
  commit messages, log lines, tooltips, issue and Slack text, and your replies to me. No semicolon
  in a log line either. Split the sentence in two or rephrase it. A URL or `key: value` data
  doesn't count.
- Slack messages are Slack mrkdwn, since I paste them and press Ctrl+Shift+F. That means `*bold*`
  single asterisks, `-` bullets, `[text](url)` links, backticks for code, no `#` headings or
  tables. Short prose, a list only for real lists. Save it as a `.md` and print it too. When
  reporting issues someone else raised, quote their wording.

## Where things go

- `~/Projects` holds only git repos, mirroring the GitLab groups. Non-git work (benches, notes,
  scratch) goes in `~/Workbench/<name>/`.
- A hand-off for the next session goes through the `handoff` skill, as one untracked `HANDOFF.md`
  at the repo root. Never a diary in memory, never committed.
- `~/dotfiles` is a **public** GitHub repo, so nothing in it may hint at my employer (hosts, IPs,
  product names, serials). Machine-specific values go in the `*.local` files.
