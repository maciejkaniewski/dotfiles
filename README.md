<div align="center">

# ✦ dotfiles

*Personal configuration files for a modern Linux development environment*

[![OS](https://img.shields.io/badge/OS-Linux-informational?style=flat-square&logo=linux&logoColor=white&color=303446)](https://www.linux.org/)
[![Shell](https://img.shields.io/badge/Shell-Zsh-informational?style=flat-square&logo=gnu-bash&logoColor=white&color=303446)](https://www.zsh.org/)
[![Editor](https://img.shields.io/badge/Editor-Neovim-informational?style=flat-square&logo=neovim&logoColor=white&color=303446)](https://neovim.io/)
[![Terminal](https://img.shields.io/badge/Terminal-Kitty-informational?style=flat-square&logo=gnometerminal&logoColor=white&color=303446)](https://sw.kovidgoyal.net/kitty/)
[![Theme](https://img.shields.io/badge/Theme-Catppuccin%20%7C%20Gruvbox%20%7C%20Dracula-informational?style=flat-square&logoColor=white&color=ca9ee6)](https://github.com/catppuccin/catppuccin)

</div>

---

A development environment with a consistent theme across every tool — pick [Catppuccin](https://github.com/catppuccin/catppuccin) (Frappé / Macchiato / Mocha), [Gruvbox](https://gruvbox.org/) Dark, or [Dracula](https://draculatheme.com/) at setup — optimized for embedded C/C++ and Python development.

---

## Stack

| Category | Tool |
|---|---|
| Terminal | [Kitty](https://sw.kovidgoyal.net/kitty/) |
| Shell | [Zsh](https://www.zsh.org/) + [Oh My Zsh](https://ohmyz.sh/) + [Powerlevel10k](https://github.com/romkatv/powerlevel10k) |
| Editor | [Neovim](https://neovim.io/) with [lazy.nvim](https://github.com/folke/lazy.nvim) |
| Editor (GUI) | [Zed](https://zed.dev/) (vim mode, Neovim keymap parity), [VS Code](https://code.visualstudio.com/) |
| AI | [Claude Code](https://claude.ai/code) |
| Git pager | [delta](https://github.com/dandavison/delta) |
| Git TUI | [lazygit](https://github.com/jesseduffield/lazygit) |
| File viewer | [bat](https://github.com/sharkdp/bat) |
| Fuzzy finder | [fzf](https://github.com/junegunn/fzf) |
| Find / grep | [fd](https://github.com/sharkdp/fd) + [ripgrep](https://github.com/BurntSushi/ripgrep) |
| Listing | [eza](https://github.com/eza-community/eza) |
| Navigation | [zoxide](https://github.com/ajeetdsouza/zoxide) |
| Python | [uv](https://docs.astral.sh/uv/) |
| Fonts | [FiraCode Nerd Font](https://github.com/ryanoasis/nerd-fonts) (editor + terminal, with ligatures), [MesloLGS NF](https://github.com/romkatv/powerlevel10k#meslo-nerd-font-patched-for-powerlevel10k) (Powerlevel10k symbols) |

---

## Installation

```bash
git clone git@github.com:maciejkaniewski/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh -s        # full bootstrap (fresh machine)
./install.sh           # symlinks only
```

### Script flags

| Flag | Description |
|---|---|
| _(none)_ | Create dotfile symlinks |
| `-s`, `--setup` | Full system bootstrap — packages, tools, shell, fonts, symlinks |
| `-c`, `--clean` | Remove all dotfile symlinks |
| `-v`, `--verify` | Check the installed toolchain actually works |
| `--theme` | Pick or re-apply the color theme and nothing else — the same step `--setup` ends with |
| `--identity` | Set your git name and email, and pick the personal or work profile (`~/.zshrc.local`, `~/.ssh/config.local`), and nothing else |
| `--llvm [version]` | Show or change which LLVM/Clang version the toolchain runs on this machine — see [Choosing an LLVM version](#choosing-an-llvm-version) |
| `-h`, `--help` | Show usage |

`--setup` runs `apt update && upgrade`, installs all tools listed below, sets Zsh as the default shell and Kitty as the default terminal, and sets up [serial port access](#serial-ports). Safe to re-run — every step is skipped if already satisfied. Works from bash on a fresh machine; log out and back in afterwards so the session starts with Zsh, then open Kitty. Tested from a fresh Ubuntu 26.04 install; used daily on 24.04.

`--setup` ends with the same checks `--verify` runs on its own. They exercise the tools rather than just looking for them on `PATH` — compile and run C and C++ with both gcc and clang, cross-compile for cortex-m4 and link against newlib, drive `clangd`, build a throwaway CMake project with Ninja, confirm every tool is at its [pinned version](#pinned-tool-versions), and scan for dangling symlinks. A failed check is an `✗` line and a non-zero exit, so a run can't report success over a broken toolchain. Needs no sudo.

At the end of `--setup` you are asked for your git name and email, which go into `~/.gitconfig.local`, and for a profile (personal or work), which copies the matching `~/.zshrc.local` and `~/.ssh/config.local` templates. The work profile adds an SSH block for machines on the local network. A `~/.zshrc.local` or `~/.ssh/config.local` you have edited is replaced only if you answer yes. None of these files is tracked in dotfiles — they stay machine-local.

**Using these dotfiles yourself** — nothing in the repo is tied to one person. Clone it, run `./install.sh -s`, and enter your own name and email at the Identity step (`./install.sh --identity` changes them later). HTTPS git credentials come from your own Bitwarden vault — see [Bitwarden for git credentials](#bitwarden-for-git-credentials).

### Pinned tool versions

The build toolchain is installed at exact versions, set in [`versions`](versions) at the repo root. They mirror the firmware release CI image, so a local build compiles and formats exactly like a release build:

| Tool | Version | Why exact |
|---|---|---|
| LLVM | 18.1.8 | `clang-format`, `clangd`, `clang-tidy`, `lld`. Firmware builds and release CI accept only clang-format 18.1.8, because other patch levels format the same code differently; Zed formats through clangd, so it stays on 18.1.8 too |
| clang compiler | 19 | `clang` and `clang++` from apt's `clang-19`, with its libclang for bindgen. Ubuntu 22.04 doesn't package it, so there `--setup` adds the apt.llvm.org repository first. C23 code (`constexpr` objects) needs clang 19 or newer |
| Arm GNU Toolchain | 15.3.rel1 (GCC 15.3.1) | The compiler firmware releases are built with |
| CMake | 4.4.2 | Same as the release image |
| Ninja | 1.13.2 | Same as the release image |
| Ruff | 0.16.1 | Formatter output changes between releases, and projects set `required-version` to it |

`--setup` installs each one at exactly that version, moving down as well as up, and `--verify` fails when one has drifted. To change one on a single machine, put the same `key=version` line in `~/.config/dotfiles/versions` (untracked) and re-run `./install.sh --setup`; `latest` tracks upstream instead. Tools not in the file always track the newest release.

### Choosing an LLVM version

LLVM follows the `llvm=` line in `versions` (18.1.8). `--llvm` overrides it on this machine and installs the result straight away:

```bash
./install.sh --llvm              # status: the pin, where it comes from, the active version, what's on disk
./install.sh --llvm 19.1.7       # pin this machine to an exact version
./install.sh --llvm 19           # newest patch in the 19.x series
./install.sh --llvm latest       # track the newest release on this machine
./install.sh --llvm default      # drop the override and follow the versions file again
./install.sh --llvm clean        # drop every inactive tree under /opt
```

The override is stored in `~/.config/llvm/version` — untracked, so it never follows this repo to another box — and every later `./install.sh --setup` honours it instead of quietly moving you off it. `--verify` fails if the pin and `/opt/llvm` ever disagree.

LLVM 18 and older were built on Ubuntu 18.04 and need `libtinfo.so.5`, which Ubuntu dropped in 24.04. When it is missing, `--setup` installs Ubuntu 22.04's `libtinfo5` package (it depends only on libc), so clang, clangd and libclang start on 24.04 and 26.04 too.

Rust crates that parse C headers (bindgen, clang-sys) load libclang by themselves. With the apt compiler they find apt's libclang-19, which matches it. Without a `clang=` line, `.zshrc` sets `LIBCLANG_PATH=/opt/llvm/lib` whenever the `clang` on `PATH` comes from that tree, so the library always matches the driver.

The pinned version owns `lld`, `ld.lld`, `clangd`, `clang-format`, `clang-tidy` and the `llvm-*` utilities on `PATH`. `clang` and `clang++` come from apt's `clang-19` while `versions` has a `clang=` line; remove it and they come from `/opt/llvm` too. Both editors invoke bare `clangd` off `PATH`, so they follow the pin with no config changes.

**Switching is a symlink repoint, not a download.** The previous version is kept under `/opt` — `/opt/llvm` is a stable alias for whichever versioned tree is active, and the `/usr/local/bin` entry points all go through it. Two trees are kept (the active one and the most recently installed other one); anything beyond that is pruned automatically, and `--llvm clean` drops the spare. Budget ~7-12GB per tree.

One upstream wrinkle worth knowing about: LLVM renamed its Linux release assets at 19.1.0, so 18.x and below ship as `clang+llvm-<version>-x86_64-linux-gnu-ubuntu-NN.NN.tar.xz` while 19.1.0+ ship as `LLVM-<version>-Linux-X64.tar.xz` (Linux ARM64 only exists from 20.1.0). `--llvm` resolves the right asset name per version, so both naming schemes work and the directory under `/opt` is named after whichever one upstream published.

### What `--setup` installs

**System packages (apt)**

| Package | Description |
|---|---|
| `build-essential` | Base compilation tools (make, libc-dev) |
| `curl` | Command-line HTTP client |
| `fonts-symbola` | Unicode symbol font (required for Claude Code icons) |
| `g++` | GNU C++ compiler |
| `gcc` | GNU C compiler |
| `git` | Version control system |
| `libxkbcommon-x11-0` | X11 keyboard library the prebuilt Kitty needs to open a window (missing on a fresh 26.04) |
| `python3-dev` | Python headers and `libpython`, which building and testing Python extensions written in Rust or C links against |
| `tree` | Display directory structure as a tree |
| `unzip` | Extract ZIP archives, used to install fonts and StyLua |
| `valgrind` | Memory error detector and profiler |
| `wget` | Command-line file downloader |
| `zsh` | Z shell |

**Command-line tools**

| Tool | Version | Description |
|---|---|---|
| [delta](https://github.com/dandavison/delta) | latest | Git diff viewer |
| [lazygit](https://github.com/jesseduffield/lazygit) | latest | Terminal UI for git |
| [glab](https://gitlab.com/gitlab-org/cli) | latest | GitLab CLI — merge requests, pipelines and issues from the terminal (gitlab.com `.deb`; replaces Ubuntu's much older apt package). Log in once per host with `glab auth login --hostname <your GitLab host>`; the token stays in `~/.config/glab-cli/`, which is not tracked |
| [bat](https://github.com/sharkdp/bat) | latest | Syntax-highlighted file viewer |
| [fzf](https://github.com/junegunn/fzf) | latest | General-purpose fuzzy finder (GitHub release) |
| [eza](https://github.com/eza-community/eza) | latest | Modern `ls` replacement with icons and git status (GitHub release — not in Ubuntu's apt repos until 23.10+) |
| [ripgrep](https://github.com/BurntSushi/ripgrep) | latest | Fast recursive search used by Telescope's live grep (GitHub release) |
| [fd](https://github.com/sharkdp/fd) | latest | Fast, `.gitignore`-aware file finder used by Telescope and fzf (GitHub release; binary is named `fd` directly, no `fdfind` symlink needed) |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | latest | Smarter `cd` that learns your most-used directories (GitHub release) |
| [direnv](https://direnv.net/) | latest | Loads and unloads a directory's `.envrc` as you `cd` in and out; Powerlevel10k already has a segment for it (GitHub release) |
| [dust](https://github.com/bootandy/dust) | latest | `du` with a tree and bars, biggest first (GitHub release) |
| [duf](https://github.com/muesli/duf) | latest | `df` as a readable table of disks (GitHub `.deb`) |
| [btop](https://github.com/aristocratos/btop) | latest | Interactive process and resource monitor (GitHub release; theme follows the active theme picker) |
| [jq](https://github.com/jqlang/jq) | latest | Command-line JSON processor, required by Claude Code status line (GitHub release) |
| [Bitwarden CLI](https://bitwarden.com/help/cli/) | latest | `bw`, backs the git credential helper for HTTPS remotes — see [Bitwarden for git credentials](#bitwarden-for-git-credentials) (GitHub release `cli-v*`, native zip — no Node needed) |

**Build toolchain**

| Tool | Version | Description |
|---|---|---|
| [CMake](https://cmake.org/) | 4.4.2 | Cross-platform build system generator (GitHub release) |
| [ninja](https://github.com/ninja-build/ninja) | 1.13.2 | Fast build system, used with cmake (GitHub release) |
| [Meson](https://mesonbuild.com/) | latest | Build system for C projects that use it (`uv tool`; apt's is too old for C23 projects, which need ≥ 1.4) |
| [Arm GNU Toolchain](https://gitlab.arm.com/tooling/gnu-toolchains-for-arm) | 15.3.rel1 | Bare-metal `arm-none-eabi-gcc`/`g++`/`gdb`/`objcopy`/etc. cross-toolchain (GitLab generic package — not packaged for apt at all) |
| [LLVM/Clang tools](https://github.com/llvm/llvm-project) | 18.1.8 | `clangd`, `clang-format`, `clang-tidy`, `clang`, `lld` (GitHub release; ~1-2GB download, 7-12GB extracted — only the entry points are symlinked out of the full LLVM tree, on `PATH` for Zed, Neovim and the CLI). Change it with `--llvm` — see [Choosing an LLVM version](#choosing-an-llvm-version) |
| [Rust](https://www.rust-lang.org/) | stable | `rustc`, `cargo`, `rustfmt`, `clippy` (official rustup installer; also builds the tree-sitter CLI on glibc < 2.39) |

**Python**

| Tool | Version | Description |
|---|---|---|
| [uv](https://docs.astral.sh/uv/) | latest | Python versions, projects and virtualenvs — replaces pyenv + Poetry (standalone installer, updates itself with `uv self update`; never edits shell rc files). Not pinned: a newer uv reads older projects fine |

**Editor tooling**

| Tool | Version | Description |
|---|---|---|
| [tree-sitter CLI](https://github.com/tree-sitter/tree-sitter) | latest | Compiles Neovim treesitter parsers. Required by nvim-treesitter `main` (needs ≥ 0.26.1; apt ships 0.20.8, so this is a GitHub release) |
| [Ruff](https://github.com/astral-sh/ruff) | 0.16.1 | Python linter/formatter (`uv tool`, on `PATH` for Zed, Neovim and the CLI) |
| [basedpyright](https://github.com/DetachHead/basedpyright) | latest | Python type checker (`uv tool`, on `PATH` for Zed, Neovim and the CLI) |
| [StyLua](https://github.com/JohnnyMorganz/StyLua) | latest | Lua formatter (GitHub release, on `PATH` for Zed, Neovim and the CLI) |
| [shellcheck](https://www.shellcheck.net/) | latest | Lints shell scripts; `--verify` runs it on `install.sh` and fails on any warning (`uv tool`, from the `shellcheck-py` package) |

**Shell and fonts**

| Tool | Version | Description |
|---|---|---|
| [Oh My Zsh](https://ohmyz.sh/) | latest | Zsh framework |
| [Powerlevel10k](https://github.com/romkatv/powerlevel10k) | latest | Zsh prompt theme |
| FiraCode Nerd Font | latest | Programming ligature font with Nerd Font icons |
| MesloLGS NF | — | Nerd font for Powerlevel10k |

**Applications**

| Tool | Version | Description |
|---|---|---|
| [Kitty](https://sw.kovidgoyal.net/kitty/) | latest | GPU-accelerated terminal |
| [Neovim](https://neovim.io/) | pinned `v0.12.5` | Code editor (release tarball). Pinned, not latest — see [Why Neovim is pinned](#why-neovim-is-pinned) |
| [Zed](https://zed.dev/) | latest | GPU-accelerated collaborative editor (official installer) |
| [Visual Studio Code](https://code.visualstudio.com/) | latest | Code editor (Microsoft apt repo) |
| [Claude Code](https://claude.ai/code) | latest | Anthropic AI CLI (native installer in `~/.local/bin`; auto-updates, no sudo) |

**Serial ports** — see [Serial ports](#serial-ports)

| What | Description |
|---|---|
| `dialout` group | Adds you to it, so USB-serial adapters open without sudo or `chmod` |
| `98-ftdi-latency.rules` | Copied into `/etc/udev/rules.d`; sets every FTDI port's latency timer to 1 ms on plug-in |
| `ports` | Lists USB serial ports and watches them being plugged in and out (linked into `~/.local/bin`) |

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

## Machine-local files

These files are **not** tracked in dotfiles — they are machine-specific and generated during setup:

| File | Purpose |
|---|---|
| `~/.gitconfig.local` | Git name and email for this machine (`--identity` writes them; other keys you add, such as a signing key, are kept) |
| `~/.zshrc.local` | Shell overrides for this machine (copied from a profile template) |
| `~/.ssh/config.local` | SSH hosts for this machine (copied from a profile template), read before the shared `~/.ssh/config` — see [SSH](#ssh) |
| `~/.claude/settings.json` | Claude Code settings: your model, effort, theme, permissions. A plain file, **not** a symlink: `install.sh` overlays the repo's stable `.claude/settings.base.json` (env, hooks, status line, plugins) onto it, so changing the model or theme never dirties the repo. Repo keys win; to change a hook, edit the base file and re-run `./install.sh` |

Never put `BW_SESSION` (the unlocked Bitwarden vault key) in either file — see [Bitwarden for git credentials](#bitwarden-for-git-credentials).

Templates for `~/.zshrc.local` live in the repo as `.zshrc.local.personal` and `.zshrc.local.work`, and for `~/.ssh/config.local` as `.ssh/config.local.personal` and `.ssh/config.local.work`. Add shared personal/work shell config there; add truly machine-specific things (API keys, VPN aliases) directly to `~/.zshrc.local`.

---

## Kitty

The Kitty terminal includes a custom Python status bar (`tab_bar.py`) rendered at the bottom alongside tabs. It refreshes every 5 seconds and shows:

`󰟀 hostname  󰍛 cpu%  freq  󰍺 ram%  used/total  󰔏 CPU°C  GPU°C  󰤨 ↓speed ↑speed  dBm  󰁹 bat%  󰃭 date  󰥔 time`

The status bar is adaptive — lower-priority segments (hostname, CPU frequency, temperatures, date) are dropped first when tabs fill the bar.

**Key bindings**

| Key | Action |
|---|---|
| `F2` | Open Neovim in current directory |
| `F3` | Save the current layout as a session |
| `F4` | Browse saved sessions and switch to one |
| `F5` | Back to the previously active session |
| `Ctrl+0` | Back to the previously active tab |
| `Ctrl+Shift+M` | Zoom the current split to the whole tab and back |
| `Ctrl+Shift+G` | Lazygit over the current window, in its directory |
| `Alt+Arrows` | Move to the split in that direction |
| `Alt+Shift+Arrows` | Swap the current split with its neighbour that way |
| `Ctrl+Shift+Y` | Copy the last command's output straight to the clipboard |
| `Ctrl+Shift+Enter` | New split window in the current directory |
| `Ctrl+Shift+T` | New tab in the current directory |
| `Ctrl+Shift+F5` | Reload config |

**Sessions**

`F3` writes the live layout — OS windows, tabs, splits, working directories and
the programs running in them — to a file under
`~/.local/share/kitty/sessions`, then opens it in `$EDITOR` to review. `F4`
lists what's there and switches to one.

Two flags carry the weight. `--use-foreground-process` is what records `nvim`,
`lazygit` or a `tail -f`; without it every pane comes back as a bare shell.
`--base-dir` pins the output directory, because kitty launched from a desktop
shortcut does not start in `$HOME` and the save prompt would otherwise default
to whatever that happened to be.

`Ctrl+Shift+Enter` (`new_window_with_cwd`) is the companion: windows created
that way join the active session rather than falling outside it.

This layers with the Neovim sessions above rather than duplicating them — kitty
restores the terminal layout and relaunches `nvim` in the right directory,
`<leader>qs` then restores the buffers and splits inside it.

Session files can also be written by hand (`layout tall`, `cd …`,
`launch --title "Build" …`) and loaded with `kitty --session <file>`, or set as
`startup_session` in `kitty.conf`. `save_as_session` is also ssh-kitten aware:
it records the remote working directory and running program.

---

## Neovim

### Plugins

**LSP & Language Support**

| Plugin | Purpose |
|---|---|
| [williamboman/mason.nvim](https://github.com/williamboman/mason.nvim) | LSP/tool installer |
| [WhoIsSethDaniel/mason-tool-installer.nvim](https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim) | Auto-install LSP servers and formatters via Mason |
| [neovim/nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) | LSP configs (clangd, basedpyright, ruff, lua_ls) |
| [saghen/blink.cmp](https://github.com/Saghen/blink.cmp) | Completion engine — LSP, snippet, buffer and path sources plus `:` cmdline completion, with matching/sorting in a prebuilt Rust binary. Pinned to `1.*` on upstream's advice (v2 is still breaking). Replaced nvim-cmp and its four `cmp-*` source plugins |
| [L3MON4D3/LuaSnip](https://github.com/L3MON4D3/LuaSnip) | Snippet engine |
| [rafamadriz/friendly-snippets](https://github.com/rafamadriz/friendly-snippets) | Snippet content (Python, C/C++, Lua, …) — LuaSnip ships none of its own |
| [stevearc/conform.nvim](https://github.com/stevearc/conform.nvim) | Formatting (clang-format, ruff, stylua) |

**Syntax & Treesitter**

| Plugin | Purpose |
|---|---|
| [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) | Parsers + queries (tracks `main`; `master` is frozen at Neovim 0.11 — see [Why Neovim is pinned](#why-neovim-is-pinned)). Highlighting and indentation are activated by `treesitter.lua` itself, since `main` ships neither |
| [nvim-treesitter-textobjects](https://github.com/nvim-treesitter/nvim-treesitter-textobjects) | Syntax-aware text objects (function, class/struct, parameter, loop, conditional, call, return, assignment, number, bitshift) |
| [nvim-treesitter-context](https://github.com/nvim-treesitter/nvim-treesitter-context) | Sticky function/class header while scrolling |

**Navigation**

| Plugin | Purpose |
|---|---|
| [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) | Fuzzy finder (tracks `master`, not the frozen `0.1.x` branch — the latter predates Neovim 0.11's LSP API changes and warns on 0.11+) |
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
| [sphamba/smear-cursor.nvim](https://github.com/sphamba/smear-cursor.nvim) | Animated cursor movement |
| [folke/which-key.nvim](https://github.com/folke/which-key.nvim) | Keymap popup hints |
| [folke/zen-mode.nvim](https://github.com/folke/zen-mode.nvim) | Centers the buffer in a 100-column window (`<leader>uz`, same key as Zed) — purely centering, gutter and statusline untouched |
| [folke/todo-comments.nvim](https://github.com/folke/todo-comments.nvim) | Highlighted TODO/FIXME/NOTE comments |
| [kevinhwang91/nvim-ufo](https://github.com/kevinhwang91/nvim-ufo) | Better folding with fold count display |
| [HiPhish/rainbow-delimiters.nvim](https://github.com/HiPhish/rainbow-delimiters.nvim) | Colored bracket/delimiter nesting |

**Editing**

| Plugin | Purpose |
|---|---|
| [windwp/nvim-autopairs](https://github.com/windwp/nvim-autopairs) | Auto-close brackets and quotes |
| [kylechui/nvim-surround](https://github.com/kylechui/nvim-surround) | Add/change/delete surrounding characters |
| [okuuva/auto-save.nvim](https://github.com/okuuva/auto-save.nvim) | Auto-save on idle — refuses to save over a file changed on disk (see [Editing alongside Claude Code](#editing-alongside-claude-code)) |
| [m4xshen/hardtime.nvim](https://github.com/m4xshen/hardtime.nvim) | Learn better Vim motions — `hjkl` capped at 3 repeats, but arrow keys and mouse scrolling left enabled |

---

### Keymaps

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

**Folds**

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
| `<leader>uz` | Toggle zen / centered layout (same key as Zed's `space u z`) |

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

### Snippets

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

**Zed parity.** friendly-snippets is a Neovim plugin with no Zed equivalent, so
`.config/zed/snippets/python.json` hand-mirrors the prefixes in the table above —
the same trigger expands to the same code in both editors. Zed reads VS Code
snippet format from `~/.config/zed/snippets/<language>.json`; bodies use 4 spaces
to match `tab_size: 4` / `hard_tabs: false`. Adding a snippet to that file is the
way to extend Zed; for Neovim-only additions, point a second loader at your own
directory rather than editing the plugin.

---

### Editing alongside Claude Code

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

#### The one case you have to resolve by hand

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

## Zed

[Zed](https://zed.dev) is set up as a second editor that reuses the Neovim muscle memory. `settings.json` enables `vim_mode` and matches the core editor behaviour; `keymap.json` re-creates the `<leader>`-key mappings on top of Zed's built-in vim bindings. Nothing that Zed's vim mode already provides (surround with `ys`/`cs`/`ds`, folds `zM`/`zR`, `ctrl-w` window motions, `gd`) is overridden.

**Theme** — a single `"theme": "Catppuccin <Flavor>"`, `"theme": "Gruvbox Dark"`, or `"theme": "Dracula"` string that follows the active theme picker (no OS-driven light/dark switching, matching kitty/bat/fzf/eza). Catppuccin and Gruvbox are built into Zed already; Dracula isn't bundled, so it's listed in `auto_install_extensions` to get pulled in automatically. `install.sh`'s `apply_theme()` patches the `"theme"` value in place on each theme switch, since `settings.json` is symlinked whole and Zed has no config-include mechanism like kitty's. A git filter keeps that from dirtying the repo: `git-filters/zed-theme` (named in `.gitattributes`, registered in the clone's `.git/config` by `install.sh`) puts the committed theme and jump-label values back before git compares the file, and puts this machine's choice back, from the untracked `~/.config/zed/theme.local`, when a pull rewrites it. Every other line of `settings.json` is tracked as usual. To commit a new default theme, stage with the filter off: `git -c filter.zed-theme.clean=cat add .config/zed/settings.json`.

**Discoverability** — the native which-key popup is enabled (`which_key.enabled`, 1000 ms delay). Hold `<space>` (or any prefix) and a hint of the available follow-up keys appears at the bottom, like [which-key.nvim](https://github.com/folke/which-key.nvim).

Leader is `<space>`, same as Neovim. The groups mirror which-key:

| Keys | Action | Neovim equivalent |
|---|---|---|
| `Ctrl-p` | Find files | `<C-p>` |
| `<space>fg` | Live grep (project search) | `<leader>fg` |
| `<space>/` | Fuzzy find in buffer | `<leader>/` |
| `<space>e` | File explorer panel | `<leader>e` |
| `<space>gs` | Git panel | `<leader>gs` |
| `<space>G` | Git graph (commit history) | — |
| `<space>lg` | LazyGit (terminal task) | `<leader>lg` |
| `s` / `S` | Flash-style labeled jump | `s` / `S` (flash.nvim) |
| `<space>ds` | Document symbols | `<leader>ds` |
| `<space>ws` | Workspace symbols | `<leader>ws` |
| `gr` | References | `gr` |
| `gd` / `K` | Definition / hover | `gd` / `K` |
| `<space>rn` | Rename | `<leader>rn` |
| `<space>ca` / `<space>cf` | Code action / format | `<leader>ca` / `<leader>cf` |
| `<space>ch` | Switch source/header (C/C++) | `<leader>ch` |
| `]d` / `[d` | Next / prev diagnostic | `]d` / `[d` |
| `<space>xx` | Project diagnostics | `<leader>xx` (Trouble) |
| `]c` / `[c` | Next / prev git hunk | `]c` / `[c` |
| `<space>hp` `hd` `hb` | Preview hunk / diff / blame | `<leader>hp` `hd` `hb` |
| `<space>hs` `hr` `hS` `hR` | Stage / reset hunk / stage / reset buffer | `<leader>hs` `hr` `hS` `hR` |
| `<space>uh` / `<space>ub` / `<space>uz` | Toggle inlay hints / blame / zen (centered) layout | `<leader>uh` / `<leader>ub` / — |
| `<space>tn` `tc`, `]t` `[t` | New / close / next / prev tab | `<leader>tn` `tc`, `]t` `[t` |
| `alt-j` / `alt-k` | Move current line down / up | — |
| `<space>mp` / `<space>mP` | Markdown preview / to the side | — |

**Notes**

- `gr` (references) is bound as a leaf, so it coexists with Zed's default `g r n` / `g r i` sub-menu via the key-timeout — same feel as Neovim's `timeoutlen`.
- **References as a popup** — `lsp_results_location: "picker"` makes `gr` (and any multi-result go-to) open in a filterable popup picker instead of a multibuffer tab, like Telescope in Neovim. A single result still jumps directly. Note: `ctrl-alt-p` toggles a code preview pane inside the picker — if the picker ever renders empty, press `ctrl-alt-p` to toggle the preview off/on, which resets its layout.
- Zed's git model is file/panel-centric, so a few `<leader>h*` hunk actions map to the closest Zed equivalent (e.g. `hd` opens the diff view, `ub` opens blame). Fine-grained staging lives in the git panel (`<space>g`).
- `<leader>uw` (toggle warnings) has no Zed action yet, so it's intentionally omitted. `<space>ch` (clangd switch source/header, `editor::SwitchSourceHeader`) is wired.
- **Flash jump** — Zed has no [flash.nvim](https://github.com/folke/flash.nvim), so `s`/`S` are bound to `vim::HelixJumpToWord`, which gives the flash experience: press `s`, the buffer dims and a green label appears at every jump target — type the label to jump straight there (no guessing). Works in normal and visual mode. This shadows vim's `s`/`S` (substitute); use `c`+motion (e.g. `cl`, `cw`) to substitute.
- **LazyGit** — `<space>lg` runs LazyGit via a Zed task (`tasks.json`) in a centered terminal that hides on success — mirroring `<leader>lg`. Requires `lazygit` on `PATH`.
- **Behaviour** — vim yanks/pastes use the **system clipboard** (`vim.use_system_clipboard: "always"`); saves are **non-invasive** (`remove_trailing_whitespace_on_save` / `ensure_final_newline_on_save` off) so autosave never rewrites untouched lines; **telemetry** is off.
- **Editor extras** — smart-case search, rainbow brackets (`colorize_brackets`, ≈ rainbow-delimiters), indent guides (`indent_aware`), git-colored tabs, scrollbar markers (diagnostics/search/git), 250 ms hover, preview tabs, vim command aliases (`:W`/`:Q`/`:Wq`), `redact_private_values` (masks secret-looking values), and `code_lens: "menu"` (lenses in a menu, not inline). Git panel collapses untracked files in the diff (`collapse_untracked_diff`).
- **Terminal** — `` ctrl-` `` toggles Zed's built-in terminal (right dock), running your zsh + Powerlevel10k. It's a Zed emulator, not Kitty, so the custom Kitty `tab_bar.py` status line doesn't apply; the config sets the terminal font to FiraCode Nerd Font Mono and enables a cwd breadcrumb. `ctrl-w h/j/k/l` are bound in the terminal context so vim-style pane navigation works *out* of the terminal (Zed otherwise sends `ctrl-w` to the shell); `ctrl-backspace` still deletes a word.

### Language tooling (parity with `lsp-config.lua` / `conform.nvim`)

`settings.json` wires the same LSPs and formatters the Neovim config uses:

| Area | Setting | Notes |
|---|---|---|
| clangd flags | `lsp.clangd.binary.arguments` | Same flags as Neovim, incl. `--query-driver=/opt/arm-gcc/bin/arm-none-eabi-*` so clangd extracts the ARM newlib system headers |
| Python | `basedpyright` + `ruff` (pyright/pylsp disabled) | basedpyright = types (standard mode), ruff = lint/format + organize-imports |
| Format on save | per-language `format_on_save: "on"` | Global stays `off`; only C, C++, Python, Lua auto-format. `<space>cf` still formats manually |
| Inline git blame | `git.inline_blame` | Author + time + **commit summary** at end of the current line (gitsigns parity) |
| Git panel extras | `git_panel.show_count_badge`, `commit_title_max_length: 72` | Uncommitted-change count badge; warns past the 72-char commit-title convention |

**Tool requirements** — Zed reads your shell `PATH`, so the formatters/servers must be reachable. `./install.sh --setup` provisions all of them (`ruff`/`basedpyright` via `uv tool`, `StyLua` and `clangd`/`clang-format`/`clang-tidy` from their GitHub releases), and Neovim uses the same copies:

- `clangd`, `clang-format`, `ruff`, `stylua`, `basedpyright` — installed on `PATH` by `--setup`. Neovim does not keep its own Mason copies of them: Mason puts its bin dir first on Neovim's `PATH`, so a Mason copy would run a different version from the one Zed and the CLI use (for `clangd`, it would also ignore the `--llvm` pin). `lsp-config.lua` therefore asks Mason only for `lua-language-server`, and `--setup` removes any Mason copy of the others left over from before, along with stale `~/.local/bin` shims into Mason. If a tool is missing in an editor, run `./install.sh --setup`.

### Extensions (`auto_install_extensions`)

`settings.json` declares the extensions Zed should keep installed, so a fresh machine self-provisions them and the language config actually resolves:

| Extension | Purpose |
|---|---|
| `basedpyright` | Registers the `basedpyright` server name the Python config references |
| `ruff` | Registers the `ruff` server for Python lint/format |
| `neocmake` | CMake grammar + LSP |
| `linkerscript` | `.ld` linker-script highlighting |
| `assembly` | ARM/`startup_*.s` assembly support |
| `toml` | `pyproject.toml`, `stylua.toml`, Cargo files |
| `git-firefly` | Git commit / `.gitignore` / `.gitconfig` highlighting |

---

## Git

`.gitconfig` uses [delta](https://github.com/dandavison/delta) as pager (theme follows the active theme picker, side-by-side line numbers) and enables a set of modern defaults:

| Setting | Effect |
|---|---|
| `push.autoSetupRemote` | First `git push` on a new branch creates the upstream automatically |
| `pull.rebase` | Pulls rebase instead of merge — linear history |
| `fetch.prune` | Deleted remote branches are pruned on every fetch |
| `branch.sort = -committerdate` | `git branch` lists most-recently-committed first |
| `rerere.enabled` | Records and replays conflict resolutions across rebases |
| `rebase.autosquash` / `autostash` / `updateRefs` | Smoother interactive rebases and stacked branches |
| `diff.algorithm = histogram`, `colorMoved` | Cleaner diffs; moved lines shown distinctly |
| `column.ui = auto` | Multi-column branch/tag/status listings |
| `help.autocorrect = prompt` | Offers the intended command on a typo |
| `submodule.recurse` | `checkout`, `switch` and `pull` also move submodules to the commit the branch records |
| `push.recurseSubmodules = check` | Refuses to push a commit whose submodule commit isn't pushed yet. Set explicitly: with `submodule.recurse` on, the default would be `on-demand`, which pushes the submodule itself. git applies whichever of the two it reads last, so `[push]` stays below `[submodule]` |
| `diff.submodule = log`, `status.submoduleSummary` | `git diff` / `git status` list the submodule commits that changed instead of two bare hashes |

Name and email are set per-machine in `~/.gitconfig.local` (see [Machine-local files](#machine-local-files)).

**lazygit** — theme (Catppuccin via [catppuccin/lazygit](https://github.com/catppuccin/lazygit), blue accent; Gruvbox and [dracula/lazygit](https://github.com/dracula/lazygit) adapted to match) follows the active theme picker. `config.yml` holds everything except the theme; each variant's colors live in a separate `{variant}.yml` and are merged in via the `LG_CONFIG_FILE` env var (set in `.zshrc`) rather than baked into `config.yml` directly. Diffs are rendered by delta (same theme and line numbers as `git diff`), with Nerd Font icons. Machine-local settings, such as `services:` for a self-hosted GitLab, go in `~/.config/lazygit/config.local.yml`, which `.zshrc` appends to `LG_CONFIG_FILE` when it exists.

### Bitwarden for git credentials

For HTTPS remotes (the company GitLab, say), git asks the Bitwarden vault for the login instead of prompting. `credential.helper = bw` runs `.local/bin/git-credential-bw` (linked into `~/.local/bin` by `install.sh`). SSH remotes are unaffected.

`credential.helper = bw` is in the tracked `.gitconfig`, so it is on for every machine. It does nothing until you run `bwu`, and only acts on `http(s)` remotes.

**One-time setup, per machine**

1. `./install.sh -s` installs `bw` (or grab it from [bitwarden.com/help/cli](https://bitwarden.com/help/cli/)).
2. Self-hosted or EU server? Point the CLI at it first: `bw config server https://vault.bitwarden.eu` — a per-machine setting, so no dotfiles entry.
3. In Bitwarden (app, browser or web vault), create one **Login** item per GitLab host:
   - **Name**: `git: gitlab.company.com` — the `git:` prefix is what separates it from your ordinary web login for the same site
   - **URI**: the host, e.g. `https://gitlab.company.com`
   - **Username**: your GitLab username
   - **Password**: a GitLab **personal access token** (`read_repository` + `write_repository`), not your account password — with 2FA on, GitLab rejects the account password over HTTPS. Create it under *GitLab → Preferences → Access Tokens*.
4. Log in: the first `bwu` does it for you (email, master password, 2FA code); or run `bw login` yourself once.

**Each session**

```bash
bwu                      # prompts for the master password, unlocks and syncs this shell
git pull                 # fills the credentials from the vault, no prompt
bwl                      # lock again when done (optional — see below)
```

`bwu` exports `BW_SESSION` into the current shell only. `git`, `lazygit` and `nvim` started from that shell inherit it; other terminals stay locked until you run `bwu` there. Nothing is written to disk, and closing the shell discards the key. `bwl` locks the vault and invalidates the key for every shell.

**Getting a repo onto another machine**

Which route depends on the machine. The rule everywhere: the token lives in Bitwarden, never in a file on any machine.

**Your own machine, every day** — the flow above: `bwu`, then plain `git clone https://…`. Existing SSH remotes keep working and don't use Bitwarden.

**Another machine you'll keep using** (a second laptop, your own Jetson) — install the dotfiles, then it is the same as above:

```bash
git clone https://github.com/maciejkaniewski/dotfiles.git ~/dotfiles   # HTTPS works if the repo is public
cd ~/dotfiles && ./install.sh -s
bw login                                  # once; then bwu and git clone as usual
```

**A one-off machine without the dotfiles** (a production box you reached over ssh) — pick the first route that works:

| Situation | What to do |
|---|---|
| You can copy files | Clone on your own machine, then `rsync -a --exclude .git <dir>/ <host>:<dir>/` (or `scp -r`). Nothing is stored on the server |
| You ssh in from your own machine | `ssh -A <host>`, then `git clone git@gitlab.company.com:<group>/<repo>.git` — see agent forwarding below |
| You must clone over HTTPS | `bwu` and `bwcp gitlab.company.com` on your machine; on the server `git -c credential.helper= clone https://…`, type your username and paste the token at `Password:` |
| No laptop and no browser | Put the `bw` binary on the server (`bw-linux-arm64-<version>.zip` for a Jetson, from [bitwarden/clients releases](https://github.com/bitwarden/clients/releases?q=cli-v)), `bw login`, `export BW_SESSION=$(bw unlock --raw)`, then clone with an inline helper (below), and `bw logout` afterwards — it removes the cached vault |

```bash
git -c credential.helper='!f() { [ "$1" = get ] && printf "username=%s\npassword=%s\n" "<gitlab-user>" "$(bw get password "git: gitlab.company.com")"; }; f' \
    clone https://gitlab.company.com/<group>/<repo>.git
```

`-c credential.helper=` (empty) clears any helper the machine has, so nothing is remembered. Never put the token in the clone URL: it ends up in `.git/config`, shell history and `ps`. For production hosts use a separate token: `read_repository` only, expiring after about a day.

**Agent forwarding (`ssh -A`)** lets the remote machine use the key held by your local ssh agent without ever receiving it: GitLab's challenge travels back through your ssh connection and your agent answers it.

- Needs the key loaded locally (`ssh-add -l` lists it; otherwise `ssh-add ~/.ssh/<key>`), its public half on your GitLab account, a route from the remote machine to GitLab, and a server that allows forwarding (the default; hardened hosts may not).
- Check on the remote: `ssh-add -l` should list your key, and `ssh -T git@gitlab.company.com` greets you by name.
- It exists only while the connection is open. After `exit` nothing is left behind and the clone keeps working; pulling or pushing over SSH needs another `-A` session.
- With `kitten ssh`, "the connection" is kitty's shared master, which stays open after `exit` until kitty quits, and a later `-A` login reuses a master opened without it (`ssh-add -l` then finds no agent). `.config/kitty/ssh.conf` turns sharing off for `*.local` and `192.168.*` hosts; add other hosts you forward to there. To close a master now: `ssh -O exit -o ControlPath=/run/user/$UID/kssh-<kitty-pid>-%C <user>@<host>`.
- While connected, root on the remote machine can use your agent to authenticate as you (it can't copy the key). Use it only on hosts you trust, and enable it per host (`ForwardAgent yes` under that `Host` in `~/.ssh/config`), never for `Host *`.

**What it will and won't do**

- **Read-only.** `store` and `erase` do nothing, so git never writes a token into the vault or a plaintext file, and a rejected token is not remembered.
- **Locked vault, no match, or an expired session:** prints a one-line reason to stderr and git falls back to its normal prompt.
- **Exact host match.** Bitwarden's default URI matching compares the base domain, so `gitlab.company.com` would also match every other `company.com` item (SSO, Jira). The helper only accepts items whose URI host equals the requested host.
- **Several items for the same host.** Your ordinary web login for the site shares the host with the token item, so this is normal. Name the token item starting with `git:` (e.g. `git: github.com`) and it wins. With no `git:` item, or two of them (personal and work account), it refuses to guess and prompts. Tell git which one per host, and it picks by username:

  ```bash
  git config --global credential.https://gitlab.company.com.username mac    # or set it per repo without --global
  ```
- **Never use the master password as an argument** (`bw unlock <password>`): it lands in shell history and `ps`.

**Check it**

```bash
bwu
printf 'protocol=https\nhost=gitlab.company.com\n\n' | git credential fill   # prints the stored username and token
bwl
printf 'protocol=https\nhost=gitlab.company.com\n\n' | git credential fill   # locked: says so, then asks for a username
```

Rotating the token: edit the Bitwarden item. The next `bwu` runs `bw sync`, which picks the change up.

---

## SSH

`~/.ssh/config` links to `.ssh/config`, which sets two things for every host:
`ServerAliveInterval 15`, so a session over a dropped link (Wi-Fi, suspend)
exits after about 45 seconds instead of freezing, and `HashKnownHosts no`, so
new `known_hosts` entries stay readable and `ssh`, `scp` and `s` can
Tab-complete them (Ubuntu hashes them by default). `.zshrc` sets the `use-ip`
completion style so IP addresses complete too: zsh leaves them out by default,
and most machines on a local network have no name. It also drops zsh's cached host list after
every command, so a machine completes right after your first login to it, not
only in the next shell.

Hosts that belong to one profile go in `~/.ssh/config.local`. `.ssh/config`
includes it first, and ssh keeps the first value it finds, so it overrides the
shared settings. `--setup` copies it from `.ssh/config.local.work` or
`.ssh/config.local.personal` along with `~/.zshrc.local`. The work one covers
machines on the local network (`*.local`, `192.168.*`): it has a commented-out
`User` line for a default login, and records a new or reflashed machine's host key without asking
(`accept-new`; a changed key for a host already in `known_hosts` is still
refused). On a machine set up before this existed, copy it by hand:
`install -m 600 ~/dotfiles/.ssh/config.local.work ~/.ssh/config.local`. ssh
refuses config files that group or others can write, so `install.sh` keeps
`.ssh/config` at `644` and the copy at `600`.

`s <host>` is `kitten ssh <host>` (inside kitty only). It is a function
completed like `ssh`, because kitten's own completer prints an error on every
Tab that matches nothing: it can't handle the anchored matchers in Oh My Zsh's
`matcher-list`. For local-network machines
`.config/kitty/ssh.conf` turns kitty's connection sharing off (see agent
forwarding under [Bitwarden for git credentials](#bitwarden-for-git-credentials)),
so every login authenticates on its own. Run `ssh-copy-id <host>` once per
machine and that is your key instead of a password.

| Task | How |
|---|---|
| Copy a file during a `kitten ssh` session, without a second login | On the remote: `kitten transfer <remote file> <local dir>`, or `kitten transfer --direction=upload <local file> <remote dir>`. Give local paths in full: the remote shell expands `~` to the remote home |
| Kill a frozen session | `Enter`, then `~.` |
| A machine was reflashed ("REMOTE HOST IDENTIFICATION HAS CHANGED") | `ssh-keygen -R <host>`, then log in again |

---

## Shell

Zsh plugins: `git` `zsh-syntax-highlighting` `zsh-autosuggestions` `zsh-bat` `fzf` `fzf-tab` `fzf-git`

**zsh-syntax-highlighting** — colors follow the active theme picker via `~/.config/zsh-syntax-highlighting/active.zsh` (sourced before the plugin activates, per [catppuccin/zsh-syntax-highlighting](https://github.com/catppuccin/zsh-syntax-highlighting)'s own requirement; Gruvbox hand-ported, Dracula adapted from [dracula/zsh-syntax-highlighting](https://github.com/dracula/zsh-syntax-highlighting), to the same style keys).

**Powerlevel10k** — prompt segment colors follow the active theme picker via `~/.config/p10k/active.zsh`, sourced right after `~/.p10k.zsh` so it only overrides the ~100 `POWERLEVEL9K_*_FOREGROUND` colors (using p10k's own `'#rrggbb'` support) without touching the generated layout, icons, or segment order. Each of the 5 themes maps every segment to one of ~13 semantic roles (blue, green, red, yellow, peach, teal, mauve, ...), so even rarely-seen segments (aws, kubecontext, battery, ...) stay on-theme. The branch name and git-status icon color are set separately: `~/.p10k.zsh`'s `my_git_formatter()` hardcodes those as raw 256-color codes rather than exposing them as `POWERLEVEL9K_*` variables, so each theme file also redefines that function (sourced after `.p10k.zsh`, same colors, just swapping in the theme's palette) plus the two `POWERLEVEL9K_VCS_*_VISUAL_IDENTIFIER_COLOR` variables.

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

---

## Serial ports

`--setup` makes USB-serial adapters usable as soon as they are plugged in:

- **Access.** Ubuntu gives every `ttyUSB*` and `ttyACM*` to the `dialout` group with read/write access, so `--setup` adds you to it. Log out and back in once for it to apply.
- **Latency.** FTDI chips hold received bytes for up to 16 ms before sending a short packet, which stalls request/response protocols. [`etc/udev/rules.d/98-ftdi-latency.rules`](etc/udev/rules.d/98-ftdi-latency.rules) sets that timer to 1 ms on every FTDI port. It matches the kernel driver (`ftdi_sio`), not a vendor/product ID or serial number, so it covers FT232R, FT2232, FT4232, FT232H and every other chip the driver supports. Other chips (CH340/CH343, CP210x, CDC-ACM) have no latency timer on Linux and are left alone.

The rule is copied into `/etc/udev/rules.d`, not symlinked, and takes effect from the next plug-in. Check a port with `cat /sys/bus/usb-serial/devices/ttyUSB0/latency_timer`. `--verify` fails when you are not in `dialout` or the installed rule differs from the repo's.

Per-device names and exceptions are machine-specific, so they stay out of the repo. Put them in a `99-*.rules` file in `/etc/udev/rules.d`: it runs after this one, so a `RUN` there can set a different latency for one adapter.

**`ports`** shows what is plugged in, from udev and `/sys` (no root needed):

```
$ ports
DEVICE        ALIAS            PRODUCT            SERIAL  DRIVER    LATENCY  PORT  STABLE PATH
/dev/ttyUSB0  /dev/FT2232_CH0  Dual RS232-HS (A)  —       ftdi_sio  1 ms     3-1   /dev/serial/by-id/usb-FTDI_Dual_RS232-HS-if00-port0
/dev/ttyUSB1  /dev/FT2232_CH1  Dual RS232-HS (B)  —       ftdi_sio  1 ms     3-1   /dev/serial/by-id/usb-FTDI_Dual_RS232-HS-if01-port0

$ ports -w
DEVICE        ALIAS            PRODUCT            SERIAL  DRIVER    LATENCY  PORT  STABLE PATH
/dev/ttyUSB0  /dev/FT2232_CH0  Dual RS232-HS (A)  —       ftdi_sio  1 ms     3-1   /dev/serial/by-id/usb-FTDI_Dual_RS232-HS-if00-port0
/dev/ttyUSB1  /dev/FT2232_CH1  Dual RS232-HS (B)  —       ftdi_sio  1 ms     3-1   /dev/serial/by-id/usb-FTDI_Dual_RS232-HS-if01-port0

Watching for plug and unplug — Ctrl-C to stop
20:24:36  − /dev/ttyUSB0  /dev/FT2232_CH0  Dual RS232-HS (A)  —
20:24:36  − /dev/ttyUSB1  /dev/FT2232_CH1  Dual RS232-HS (B)  —
20:24:38  + /dev/ttyUSB0  /dev/FT2232_CH0  Dual RS232-HS (A)  —         ftdi_sio  1 ms  USB port 3-1
20:24:38  + /dev/ttyUSB1  /dev/FT2232_CH1  Dual RS232-HS (B)  —         ftdi_sio  1 ms  USB port 3-1
20:24:41  − /dev/ttyUSB0  /dev/FT2232_CH0  Dual RS232-HS (A)  —
20:24:41  − /dev/ttyUSB1  /dev/FT2232_CH1  Dual RS232-HS (B)  —
20:24:43  + /dev/ttyUSB0                   FT232R USB UART    B00329ZK  ftdi_sio  1 ms  USB port 3-1
```

| Command | Does |
|---|---|
| `ports` | Lists every USB serial port: product string, serial number, driver, latency timer, USB port and stable path. FT2232/FT4232 channels are named `(A)`, `(B)`, … A name a local udev rule gives a port (`SYMLINK+="FT2232_CH0"`) shows in an ALIAS column, which appears only when some port has one |
| `ports -w` | Lists them, then prints a timestamped `+` or `−` line each time an adapter is plugged in or out, until `Ctrl-C` |

Colours follow the theme picked with `--theme`, in the same roles as the prompt; the latency shows green at 1 ms and orange at anything else. Piped output is plain text.

The stable path (`/dev/serial/by-id/…`) is created by udev for every adapter. It names the adapter by its product and serial number, so it stays the same whichever USB socket it is in and whichever `ttyUSB` number it gets — usually no need for a per-device alias. Pass it to any tool that takes a port, e.g. `--LINK_UART_PORT`.

---

## Structure

```
dotfiles/
├── .claude/
│   ├── settings.base.json             # stable part of ~/.claude/settings.json, merged in by install.sh
│   ├── nvim-checktime.sh              # PostToolUse hook — tells running nvim to reload files Claude wrote
│   └── statusline-git.sh
├── .config/
│   ├── bat/
│   │   └── config
│   ├── btop/
│   │   └── themes/
│   │       └── {variant}.theme        # Catppuccin/Gruvbox/Dracula theme per variant
│   ├── delta/
│   │   ├── catppuccin.gitconfig
│   │   ├── gruvbox.gitconfig
│   │   └── dracula.gitconfig
│   ├── eza/
│   │   └── {variant}.yml              # Catppuccin/Gruvbox/Dracula theme per variant
│   ├── kitty/
│   │   ├── kitty.conf
│   │   ├── ssh.conf                   # kitten ssh: no shared connections to local-network machines
│   │   └── tab_bar.py
│   ├── lazygit/
│   │   ├── config.yml
│   │   └── {variant}.yml              # Catppuccin/Gruvbox/Dracula theme per variant, merged via LG_CONFIG_FILE
│   ├── p10k/
│   │   └── {variant}.zsh              # Catppuccin/Gruvbox/Dracula Powerlevel10k colors per variant
│   ├── zsh-syntax-highlighting/
│   │   └── {variant}.zsh              # Catppuccin/Gruvbox/Dracula theme per variant
│   ├── zed/
│   │   ├── settings.json
│   │   ├── keymap.json
│   │   ├── tasks.json
│   │   └── snippets/
│   │       └── python.json            # mirrors friendly-snippets prefixes for Zed
│   └── nvim/
│       ├── init.lua
│       ├── after/
│       │   └── queries/
│       │       ├── c/
│       │       │   └── textobjects.scm    # custom @shift capture for bitshifts
│       │       └── cpp/
│       │           └── textobjects.scm
│       └── lua/
│           ├── vim-options.lua
│           ├── external-edits.lua     # reload-on-external-change + auto-save clobber guard
│           └── plugins/
│               ├── alpha.lua
│               ├── autosave.lua
│               ├── autopairs.lua
│               ├── blink.lua
│               ├── conform.lua
│               ├── dropbar.lua
│               ├── gitsigns.lua
│               ├── hardtime.lua
│               ├── hlchunk.lua
│               ├── lazygit.lua
│               ├── lsp-config.lua
│               ├── lualine.lua
│               ├── neo-tree.lua
│               ├── noice.lua
│               ├── persistence.lua
│               ├── rainbow-delimiters.lua
│               ├── smear-cursor.lua
│               ├── surround.lua
│               ├── telescope.lua
│               ├── theme.lua
│               ├── todo-comments.lua
│               ├── treesitter-context.lua
│               ├── treesitter.lua
│               ├── ufo.lua
│               ├── which-key.lua
│               └── zen-mode.lua
├── .gitconfig
├── .local/
│   └── bin/
│       ├── git-credential-bw          # git credential helper — HTTPS logins from the Bitwarden vault
│       └── ports                      # list / watch USB serial ports
├── .p10k.zsh
├── .ssh/
│   ├── config                         # shared client settings, includes ~/.ssh/config.local first
│   ├── config.local.personal          # ~/.ssh/config.local template, personal profile
│   └── config.local.work              # ~/.ssh/config.local template, work profile (local-network block)
├── .zshrc
├── .zshrc.local.personal
├── .zshrc.local.work
├── .gitattributes                     # runs git-filters/zed-theme on Zed's settings.json
├── etc/
│   └── udev/
│       └── rules.d/
│           └── 98-ftdi-latency.rules  # copied to /etc by --setup: 1 ms latency on every FTDI port
├── git-filters/
│   └── zed-theme                      # keeps the theme picker's Zed edits out of git status
├── LICENSE                            # MIT
├── install.sh
└── versions                           # exact tool versions --setup installs
```

---

## License

[MIT](LICENSE) — fork it, copy from it, change it. The theme files under `.config/` (Catppuccin, Gruvbox, Dracula) come from their upstream projects, which are MIT-licensed too.
