# Neovim

## Plugins

**LSP & Language Support**

| Plugin | Purpose |
|---|---|
| [neovim/nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) | LSP configs (clangd, basedpyright, ruff, lua_ls). Every server comes from `install.sh` on `PATH`, the same copy the CLI runs, so there is no Mason |
| [saghen/blink.cmp](https://github.com/Saghen/blink.cmp) | Completion engine — LSP, snippet, buffer and path sources plus `:` cmdline completion, with matching/sorting in a prebuilt Rust binary. Pinned to `1.*` on upstream's advice (v2 is still breaking). Replaced nvim-cmp and its four `cmp-*` source plugins |
| [L3MON4D3/LuaSnip](https://github.com/L3MON4D3/LuaSnip) | Snippet engine |
| [rafamadriz/friendly-snippets](https://github.com/rafamadriz/friendly-snippets) | Snippet content (Python, C/C++, Lua, …) — LuaSnip ships none of its own |
| [stevearc/conform.nvim](https://github.com/stevearc/conform.nvim) | Formatting (clang-format, ruff, stylua). `stylua.toml` keeps Lua at 4-space indents; without it StyLua indents with tabs. Formatting a whole file still reflows hand-aligned columns (keymap tables, trailing comments) |

**Syntax & Treesitter**

| Plugin | Purpose |
|---|---|
| [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) | Parsers + queries (tracks `main`; `master` is frozen at Neovim 0.11 — see [Why Neovim is pinned](#why-neovim-is-pinned)). Highlighting and indentation are activated by `treesitter.lua` itself, since `main` ships neither |
| [nvim-treesitter-textobjects](https://github.com/nvim-treesitter/nvim-treesitter-textobjects) | Syntax-aware text objects (function, class/struct, parameter, loop, conditional, call, return, assignment, number, bitshift) |
| [nvim-treesitter-context](https://github.com/nvim-treesitter/nvim-treesitter-context) | Sticky function/class header while scrolling |

**Navigation**

| Plugin | Purpose |
|---|---|
| [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) | Fuzzy finder (tracks `master`: releases are rare, and the newest tag lacks fixes this config relies on, such as Neovim 0.12 deprecations and `grep_string` escaping) |
| [telescope-fzf-native.nvim](https://github.com/nvim-telescope/telescope-fzf-native.nvim) | Native fzf matcher for telescope (significant speed-up on large repos) |
| [neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim) | File explorer |
| [Bekaboo/dropbar.nvim](https://github.com/Bekaboo/dropbar.nvim) | Breadcrumb navigation bar |
| [folke/flash.nvim](https://github.com/folke/flash.nvim) | Jump to any visible location with 2-char labels |
| [stevearc/aerial.nvim](https://github.com/stevearc/aerial.nvim) | Symbol outline sidebar (functions, structs, classes) |
| [folke/trouble.nvim](https://github.com/folke/trouble.nvim) | Diagnostics / quickfix / symbols list panel |
| [folke/persistence.nvim](https://github.com/folke/persistence.nvim) | Session save/restore, one session per directory |

**Git**

| Plugin | Purpose |
|---|---|
| [lewis6991/gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim) | Git signs in gutter + hunk actions |
| [kdheepak/lazygit.nvim](https://github.com/kdheepak/lazygit.nvim) | Lazygit inside Neovim |

**UI & Visual**

| Plugin | Purpose |
|---|---|
| [catppuccin/nvim](https://github.com/catppuccin/nvim) | Color scheme (flavor follows the picker, transparent) — active only when Catppuccin is selected |
| [ellisonleao/gruvbox.nvim](https://github.com/ellisonleao/gruvbox.nvim) | Color scheme (dark/light follows the picker, transparent) — active only when Gruvbox is selected |
| [Mofiqul/dracula.nvim](https://github.com/Mofiqul/dracula.nvim) | Color scheme (transparent) — active only when Dracula is selected |
| [nvim-lualine/lualine.nvim](https://github.com/nvim-lualine/lualine.nvim) | Status line |
| [folke/noice.nvim](https://github.com/folke/noice.nvim) | Improved UI for cmdline, messages, LSP |
| [goolord/alpha-nvim](https://github.com/goolord/alpha-nvim) | Dashboard on startup |
| [shellRaining/hlchunk.nvim](https://github.com/shellRaining/hlchunk.nvim) | Current scope highlight + chunk indicator |
| [folke/which-key.nvim](https://github.com/folke/which-key.nvim) | Keymap popup hints |
| [folke/zen-mode.nvim](https://github.com/folke/zen-mode.nvim) | Centers the buffer in a 100-column window (`<leader>uz`) — purely centering, gutter and statusline untouched |
| [folke/todo-comments.nvim](https://github.com/folke/todo-comments.nvim) | Highlighted TODO/FIXME/NOTE comments |
| [HiPhish/rainbow-delimiters.nvim](https://github.com/HiPhish/rainbow-delimiters.nvim) | Colored bracket/delimiter nesting |

**Editing**

| Plugin | Purpose |
|---|---|
| [windwp/nvim-autopairs](https://github.com/windwp/nvim-autopairs) | Auto-close brackets and quotes |
| [kylechui/nvim-surround](https://github.com/kylechui/nvim-surround) | Add/change/delete surrounding characters |
| [okuuva/auto-save.nvim](https://github.com/okuuva/auto-save.nvim) | Auto-save on idle — refuses to save over a file changed on disk (see [Editing alongside Claude Code](#editing-alongside-claude-code)) |
| [m4xshen/hardtime.nvim](https://github.com/m4xshen/hardtime.nvim) | Learn better Vim motions — `hjkl` capped at 3 repeats, but arrow keys and mouse scrolling left enabled |

---

## Keymaps

**Leader:** `Space`

> **Tip — let which-key teach you.** Press `<Space>` and wait: a popup lists every
> leader mapping, grouped by category (`+find`, `+git hunks`, `+toggles (UI)`,
> `+tabs`, …). You don't need to memorize this table — press the prefix and read
> the menu. Prefixes are organized so each one means *one* thing: `<leader>t` is
> **tabs**, `<leader>u` is **UI toggles**, `<leader>g` is **git**, `<leader>h` is
> **git hunks**, `<leader>f` is **find**.

**LSP**

| Key | Action |
|---|---|
| `gd` | Go to definition |
| `gr` | Go to references |
| `K` | Hover documentation |
| `<leader>rn` | Rename symbol |
| `<leader>ca` | Code action |
| `<leader>cf` | Format buffer |
| `[d` / `]d` | Previous / next diagnostic |
| `<leader>ds` | Document symbols |
| `<leader>ws` | Workspace symbols |
| `<leader>d` | Show diagnostic float |
| `<leader>uh` | Toggle inlay hints (param names, inferred types) |
| `<leader>ch` | Switch between source / header (clangd, C/C++) |

**Git (gitsigns)**

| Key | Action |
|---|---|
| `]c` / `[c` | Next / previous hunk |
| `<leader>hs` / `<leader>hS` | Stage hunk / buffer |
| `<leader>hr` / `<leader>hR` | Reset hunk / buffer |
| `<leader>hp` | Preview hunk popup |
| `<leader>hi` | Preview hunk inline |
| `<leader>hb` | Blame line |
| `<leader>hd` / `<leader>hD` | Diff against index / last commit |
| `<leader>hq` / `<leader>hQ` | Hunks to quickfix / all hunks |
| `<leader>ub` | Toggle line blame |
| `<leader>uW` | Toggle word diff |
| `ih` | Select hunk (text object) |
| `<leader>lg` | Open LazyGit |

**Navigation**

| Key | Action |
|---|---|
| `<C-p>` | Find files |
| `<leader>fg` | Live grep |
| `<leader>fr` | Recent files |
| `<leader>fb` | Open buffers |
| `<leader>fw` | Grep word under cursor (or the selection, in visual mode) |
| `<leader>fd` | Diagnostics across all buffers |
| `<leader>fh` | Help tags |
| `<leader>fk` | Keymaps |
| `<leader>fR` | Resume the last picker, query and cursor intact |
| `<leader>/` | Fuzzy find in buffer |
| `<leader>e` | Toggle file explorer |
| `<leader>gs` | Git status (neo-tree) |
| `<leader>o` | Toggle symbol outline (aerial) |
| `s` | Flash jump to any visible location |
| `S` | Flash jump to a treesitter node |

**Diagnostics list (Trouble)**

| Key | Action |
|---|---|
| `<leader>xx` | Toggle diagnostics (workspace) |
| `<leader>xX` | Toggle diagnostics (current buffer) |
| `<leader>xs` | Toggle symbols panel |
| `<leader>xq` | Toggle quickfix list |

**Folds** — built in, no plugin: from the syntax tree where treesitter has a parser, by indent elsewhere, all open on start. A closed fold shows its first line with its highlighting.

| Key | Action |
|---|---|
| `zM` | Close all folds |
| `zR` | Open all folds |

**Tabs & Windows**

| Key | Action |
|---|---|
| `<leader>tn` | New tab |
| `<leader>tc` | Close tab |
| `[t` / `]t` | Previous / next tab |
| `<C-w>v` | Vertical split |
| `<C-w>s` | Horizontal split |
| `<C-w>h/j/k/l` | Navigate splits |

**Diagnostics & TODOs**

| Key | Action |
|---|---|
| `]T` / `[T` | Next / previous TODO |
| `<leader>ft` | Search TODOs |

**Toggles** (`<leader>u` — everything you switch on/off lives here)

| Key | Action |
|---|---|
| `<leader>uw` | Toggle warnings globally |
| `<leader>uh` | Toggle inlay hints (param names, inferred types) |
| `<leader>ub` | Toggle line blame |
| `<leader>uW` | Toggle word diff |
| `<leader>uz` | Toggle zen / centered layout |

**Buffer vs. disk** (`<leader>b` — for when a file changed underneath you)

| Key | Action |
|---|---|
| `<leader>bd` | Diff the buffer against the file on disk |
| `<leader>br` | Reload from disk, discarding the buffer |

**General**

| Key | Action |
|---|---|
| `<leader>qq` | Quit all |
| `<leader>qQ` | Force quit all |
| `<Esc>` | Clear search highlight + close floats |

**Sessions** (`<leader>q` — a session is written on quit, one per directory)

| Key | Action |
|---|---|
| `<leader>qs` | Restore the session for this directory |
| `<leader>ql` | Restore the last session, whichever directory it was |
| `<leader>qd` | Stop — don't save this session on exit |

The startup dashboard also has a `s` entry for the current directory's session.
Generated panels (neo-tree, aerial, trouble) are closed before a session is
written: their contents aren't read from disk, so they restore as empty windows.

**Text objects** (treesitter, work in visual + operator-pending modes)

Combine with operators: `daf` deletes a function, `cic` changes inside a struct, `yam` yanks a call. In `c` and `cpp`, `@class.outer` matches both `struct` and `enum`.

| Keys | Selects |
|---|---|
| `af` / `if` | Around / inside function |
| `ac` / `ic` | Around / inside class — **struct or enum in C** |
| `aa` / `ia` | Around / inside parameter or argument |
| `al` / `il` | Around / inside loop (`for`/`while`/`do`) |
| `a?` / `i?` | Around / inside conditional (`if`/`switch`) |
| `am` / `im` | Around / inside call (e.g. `printf(...)`) |
| `ar` / `ir` | Around / inside `return` statement |
| `in` | Inside number literal (e.g. `cin` on `0xFF`) |
| `a=` / `i=` | Around / inside assignment |
| `aS` / `iS` | Around / inside bitshift expression (`<<`, `>>`, `<<=`, `>>=`) — C/C++ only |

**Treesitter motions**

| Keys | Jump |
|---|---|
| `]f` / `[f` | Next / prev function |
| `]C` / `[C` | Next / prev class/struct/enum |
| `]l` / `[l` | Next / prev loop |
| `]?` / `[?` | Next / prev conditional |
| `]S` / `[S` | Next / prev bitshift — C/C++ only |

**Commenting** (built-in Neovim ≥ 0.10)

| Keys | Action |
|---|---|
| `gcc` | Toggle comment on current line |
| `gc{motion}` | Comment a motion (`gcap`, `gcaf`, `gcal`, etc.) |
| `gc` (visual) | Toggle comment on selection |
| `gbc` / `gb{motion}` | Block-style `/* */` comment |

---

## Snippets

LuaSnip is only an *engine* — it ships no snippets. Until
[friendly-snippets](https://github.com/rafamadriz/friendly-snippets) was added,
the `luasnip` source was wired up but silently produced nothing for every
language. It is now pulled in per-filetype on first use (`blink.lua` keeps
LuaSnip as the engine, via blink's `luasnip` preset, precisely because
friendly-snippets is in VS Code format and LuaSnip is what loads it):

```lua
require("luasnip.loaders.from_vscode").lazy_load()
```

**Keys** (same as the completion menu — nothing new to learn)

| Key | Action |
|---|---|
| `<Tab>` | Next completion item, or expand the snippet / jump to its next placeholder |
| `<S-Tab>` | Previous item, or jump to the previous placeholder |
| `<C-Space>` | Force the completion menu open |
| `<CR>` | Confirm the highlighted item (nothing is preselected, so `<CR>` stays a newline until you pick one) |

Type a prefix, `<Tab>` to expand, then `<Tab>` between the placeholders. Python
gets 67 snippets; the ones worth memorising:

| Prefix | Expands to |
|---|---|
| `ifmain` | `if __name__ == "__main__":` guard |
| `def` / `deft` | Function, without / with a `-> None` return annotation |
| `defs` | Method taking `self` |
| `class` / `classd` | Class, plain / with a base class |
| `property` | `@property` getter plus matching `.setter` |
| `for` / `forr` | `for … in …` / `for … in range(…)` |
| `while`, `with`, `ifelse` | Loop / context manager / if-else |
| `try` / `tryf` | `try/except` / `try/except/finally` |
| `lc` / `lci` / `dc` | List comprehension / with filter / dict comprehension |
| `fromim` | `from … import …` |

Run `:lua =#require("luasnip").get_snippets("python")` to see the count for a
filetype, or browse `~/.local/share/nvim/lazy/friendly-snippets/snippets/`.

To add snippets of your own, point a second LuaSnip loader at your own
directory rather than editing the plugin.

---

## Editing alongside Claude Code

Running Claude Code in one terminal and Neovim in another used to be able to eat
Claude's edits. The failure was quiet and specific:

1. Neovim holds `foo.c` in a buffer.
2. Claude writes a new version of `foo.c` to disk.
3. The buffer still holds the **old** text. Neovim's `autoread` only compares
   timestamps when it happens to regain focus, and it *never* reloads a buffer
   with unsaved changes.
4. `auto-save.nvim` fires on idle and writes the stale buffer back — with
   `silent! write`, which suppresses Neovim's usual "file has changed since
   reading it" warning.

Claude's work is gone with no message. Three pieces now prevent that; the first
two live in `lua/external-edits.lua`, the third outside Neovim entirely.

**1. Buffers reload eagerly.** `checktime` runs on `FocusGained`, `BufEnter`,
`CursorHold`, `TermLeave` and `VimResume`, so a clean buffer picks up Claude's
version almost immediately and says `reloaded foo.c (changed on disk)`.

**2. Auto-save refuses to clobber.** Every buffer remembers the mtime it last
agreed with. If the file on disk is newer, `auto-save.nvim`'s `condition` returns
false rather than writing, and you get:

```
auto-save skipped: foo.c changed on disk
<leader>bd to diff, <leader>br to reload from disk
```

**3. Claude pokes Neovim directly.** `~/.claude/nvim-checktime.sh` runs as a
`PostToolUse` hook on `Edit|Write|NotebookEdit` (wired in `.claude/settings.base.json`)
and sends `:checktime` to every running Neovim over its RPC socket. That closes
the gap between "Claude wrote the file" and "Neovim noticed" — no focus change
needed. It runs `async`, so it costs the tool call nothing, and exits quietly
when no Neovim is running.

### The one case you have to resolve by hand

If the buffer has **unsaved edits** and Claude wrote the same file, nobody can
pick a winner for you — discarding either side loses work. Neovim warns:

```
W12: Warning: File "foo.c" has changed and the buffer was changed in Vim as well
```

Nothing has been overwritten at this point: your edits are in the buffer, Claude's
are on disk, and auto-save stays blocked for that buffer until you resolve it.

| Key | Use it when |
|---|---|
| `<leader>bd` | You want to see both first — opens a vertical diff of buffer vs. disk, so you can pull individual hunks across with `do` / `dp` |
| `<leader>br` | Claude's version wins — `:edit!` reloads from disk and discards the buffer |

To keep your version instead, just `:w` — Neovim asks for confirmation (this path
is a real `:w`, not auto-save's silenced one), and writing re-syncs the stamp so
auto-save resumes.

The cheapest habit is to avoid the conflict: leave a file alone in Neovim while
Claude is working on it, and let step 1 hand you the new version. `undofile` is
on, so `u` still reaches back past a reload if you need it.

---

## Why Neovim is pinned

`install.sh` pins Neovim to an exact release (`NVIM_VERSION`) rather than
tracking latest, so a nightly never lands here by surprise: nvim-treesitter's
support policy covers only the *latest stable* and the *latest nightly*.

**0.12 is a floor, not a preference.** nvim-treesitter's `main` branch — which
`lua/plugins/treesitter.lua` now tracks — requires Neovim 0.12+ and
`tree-sitter-cli` 0.26.1 or newer (both installed by `install.sh`; Ubuntu's apt
build of the CLI is 0.20.8, far too old, so it comes from a GitHub release).

### The migration off `master`

This config used to track nvim-treesitter's `master` branch, because `main` is
an incompatible rewrite rather than a version bump. `master` is now frozen: its
last commit (2026-03-23) is *"docs(readme): list support upper bounds"*, and what
it capped was **Neovim 0.10 or 0.11**.

Neovim 0.12's own `news.txt` names the breaking change:

> The `all` option to `Query:iter_matches()`, which was introduced in Nvim 0.11
> to aid in transitioning to the new behavior, has been removed.

A query capture now hands back a *list* of nodes where it used to be a single
node. `master`'s markdown injection directive (`set-lang-from-info-string!`)
still expects the old shape, so on 0.12+ every markdown buffer threw
`attempt to call method 'range' (a nil value)`. Load order could not avoid it —
lazy.nvim prepends plugin directories to `runtimepath`, so the stale query always
won over Neovim's own working one.

Measured before the migration:

| Neovim | markdown injections | C / C++ / Python / Lua |
|---|---|---|
| 0.11.7 | works | works |
| 0.12.5 | **broken** | works |
| 0.13.0-dev | **broken** | works |

### What `main` changes

`require("nvim-treesitter.configs").setup()` does not exist on `main`. The plugin
ships parsers and queries, and **activation is the user's job** — so
`treesitter.lua` now enables highlighting and indentation itself from a
`FileType` autocommand, and installs only the parsers that are missing rather
than walking the whole list at every startup.

The same version drift is what broke `flash.nvim` on 0.13 (`undefined symbol:
search_match_lines`) — the cost of tracking nightly with pinned plugins.
