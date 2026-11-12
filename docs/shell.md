# Shell

Zsh plugins: `git` `zsh-syntax-highlighting` `zsh-autosuggestions` `zsh-bat` `fzf` `fzf-tab` `fzf-git`

**zsh-syntax-highlighting** — colors follow the active theme picker via `~/.config/zsh-syntax-highlighting/active.zsh` (sourced before the plugin activates, per [catppuccin/zsh-syntax-highlighting](https://github.com/catppuccin/zsh-syntax-highlighting)'s own requirement; Gruvbox hand-ported, Dracula adapted from [dracula/zsh-syntax-highlighting](https://github.com/dracula/zsh-syntax-highlighting), to the same style keys).

**Powerlevel10k** — prompt segment colors follow the active theme picker via `~/.config/p10k/active.zsh`, sourced right after `~/.p10k.zsh` so it only overrides the ~100 `POWERLEVEL9K_*_FOREGROUND` colors (using p10k's own `'#rrggbb'` support) without touching the generated layout, icons, or segment order. Each of the 5 themes maps every segment to one of ~13 semantic roles (blue, green, red, yellow, peach, teal, mauve, ...), so even rarely-seen segments (aws, kubecontext, battery, ...) stay on-theme. The branch name and git-status icon color are set separately: `~/.p10k.zsh`'s `my_git_formatter()` hardcodes those as raw 256-color codes rather than exposing them as `POWERLEVEL9K_*` variables, so each theme file also redefines that function (sourced after `.p10k.zsh`, same colors, just swapping in the theme's palette) plus the two `POWERLEVEL9K_VCS_*_VISUAL_IDENTIFIER_COLOR` variables.

**Transient prompt** — once a command runs, its prompt shrinks to the prompt character and the command, so scrollback reads like a transcript and copies cleanly. The first prompt after a `cd` keeps its directory and branch, so you can still see where each run of commands happened (`POWERLEVEL9K_TRANSIENT_PROMPT=same-dir` in `.p10k.zsh`).

**Git tags in the prompt** — when `HEAD` carries a tag, the prompt shows it next to the branch with a tag icon:

```
~/Projects/my-firmware    main  v1.4.2  ❯
```

Upstream p10k gates this on *not being on a branch*, so a tagged commit on `main` showed nothing — released firmware is always both. The gate is removed and the `#` separator replaced by `MY_VCS_TAG_ICON` (`\uF02B`, the same Font Awesome family as the `\uF126` branch icon). Because `my_git_formatter()` is duplicated per theme, the change lives in **all six** copies: `~/.p10k.zsh` and each `~/.config/p10k/<theme>.zsh`. The icon itself is defined once, in `.p10k.zsh` beside `POWERLEVEL9K_VCS_BRANCH_ICON`.

**Aliases** ([eza](https://github.com/eza-community/eza) — theme follows the active theme picker via `~/.config/eza/theme.yml`)

| Alias | Command |
|---|---|
| `ls` | `eza --group-directories-first --icons=auto` |
| `ll` | `eza -lah --group-directories-first --icons=auto --git` (long view + git status) |
| `la` | `eza -a --group-directories-first --icons=auto` |
| `lt` | `eza --tree --level=2 --icons=auto` |

`cpwd` copies the current directory to the clipboard, without a trailing
newline, through `kitten clipboard`. `gweb` opens the current repo's `origin`
in the browser (GitHub or GitLab, built from the remote URL, no login needed).

**uv** — `uv run <Tab>` also lists the project's own commands from
`[project.scripts]` in the nearest `pyproject.toml`, and after one of them
`--<Tab>` lists its flags with their descriptions, read from its `--help`.
Flags are only read for those commands, never for an arbitrary script, which
might ignore `--help` and simply run. `pyproject.toml` is read by zsh itself,
not Python's `tomllib`, which needs 3.11.

**just** — `just <Tab>` lists the recipes of the nearest `justfile`, and just's own flags after `-`.

**FZF** — `Ctrl+T` and `Alt+C` use [`fd`](https://github.com/sharkdp/fd) as the
backend (fast, `.gitignore`-aware, includes hidden files, skips `.git`), and both
show a preview pane — `bat` for files, `eza --tree` for directories.

| Key | Action |
|---|---|
| `Ctrl+R` | Fuzzy history search |
| `Ctrl+T` | Fuzzy file search (preview: `bat`, first 500 lines) |
| `Alt+C` | Fuzzy cd (preview: `eza --tree`, 2 levels) |
| `Tab` | Completions in fzf ([fzf-tab](https://github.com/Aloxaf/fzf-tab)); `cd <Tab>` previews each directory |
| `Ctrl+G` `Ctrl+B` / `F` / `H` / `T` / `S` / `R` | Pick git branches / changed files / commit hashes / tags / stashes / remotes ([fzf-git](https://github.com/junegunn/fzf-git.sh)); `Ctrl+G` `?` lists them all |
| `Ctrl+G` `O` | Open this repo in the browser (`gweb`) |

The preview options live in `FZF_CTRL_T_OPTS` / `FZF_ALT_C_OPTS` rather than
`FZF_DEFAULT_OPTS` on purpose: the theme picker *assigns* `FZF_DEFAULT_OPTS`
wholesale, so anything added there would be dropped the next time a theme was
applied.

**History** — Oh My Zsh already sets `share_history`, `hist_ignore_dups`,
`hist_ignore_space`, `extended_history` and `hist_verify`. On top of that,
`SAVEHIST` is raised to match `HISTSIZE` (it defaults to 10000 against a 50000
in-memory history, discarding four fifths of it at exit), and
`HIST_IGNORE_ALL_DUPS` + `HIST_REDUCE_BLANKS` are enabled so commands alternated
with others don't accumulate one copy per run.

**zoxide** — smarter `cd` that learns your most-visited directories

| Command | Action |
|---|---|
| `z <keyword>` | Jump to best-matching directory |
| `zi` | Interactive fzf picker over visited dirs |
| `z -` | Back to previous directory |

Visits are recorded in the background. zoxide `fsync`s its database on every
directory change, so while something else writes heavily (a DSView capture,
say) each `cd` used to stall the prompt waiting on the disk.
