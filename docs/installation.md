# Installation

```bash
git clone https://github.com/maciejkaniewski/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh -s        # full bootstrap (fresh machine)
./install.sh           # symlinks only
```

## Script flags

| Flag | Description |
|---|---|
| _(none)_ | Create dotfile symlinks |
| `-s`, `--setup` | Full system bootstrap — packages, tools, shell, fonts, symlinks |
| `-c`, `--clean` | Remove all dotfile symlinks |
| `-v`, `--verify` | Check the installed toolchain actually works |
| `--theme` | Pick or re-apply the color theme and nothing else — the same step `--setup` ends with |
| `--identity` | Set your git name and email, and pick the personal or work profile (`~/.zshrc.local`, `~/.ssh/config.local`), and nothing else |
| `--niri` | Add the [niri](niri.md) tiling session to the login screen, beside GNOME: builds niri, xwayland-satellite and Waybar, installs the session's tools from apt, links its configs. Once installed, `--setup` keeps it at the pinned versions |
| `--llvm [version]` | Show or change which LLVM/Clang version the toolchain runs on this machine — see [Choosing an LLVM version](toolchain.md#choosing-an-llvm-version) |
| `-h`, `--help` | Show usage |

`--setup` adds the git-core PPA, runs `apt update && upgrade`, installs all tools listed below, sets Zsh as the default shell and Kitty as the default terminal, and sets up [serial port access](serial-ports.md). Safe to re-run — every step is skipped if already satisfied. Works from bash on a fresh machine; log out and back in afterwards so the session starts with Zsh, then open Kitty. Tested from a fresh Ubuntu 26.04 install; used daily on 24.04.

`--setup` ends with the same checks `--verify` runs on its own. They exercise the tools rather than just looking for them on `PATH` — compile and run C and C++ with both gcc and clang, cross-compile a bare-metal Arm program and link it against newlib, drive `clangd`, build a throwaway CMake project with Ninja, confirm every tool is at its [pinned version](toolchain.md#pinned-tool-versions), and scan for dangling symlinks. A failed check is an `✗` line and a non-zero exit, so a run can't report success over a broken toolchain. Needs no sudo.

At the end of `--setup` you are asked for your git name and email, which go into `~/.gitconfig.local`, and for a profile (personal or work), which copies the matching `~/.zshrc.local` and `~/.ssh/config.local` templates. The work profile adds an SSH block for machines on the local network. A `~/.zshrc.local` or `~/.ssh/config.local` you have edited is replaced only if you answer yes. None of these files is tracked in dotfiles — they stay machine-local.

**Using these dotfiles yourself** — nothing in the repo is tied to one person. Clone it, run `./install.sh -s`, and enter your own name and email at the Identity step (`./install.sh --identity` changes them later). HTTPS git credentials come from your own Bitwarden vault — see [Bitwarden for git credentials](git.md#bitwarden-for-git-credentials).

## What `--setup` installs

**System packages (apt)**

| Package | Description |
|---|---|
| `build-essential` | Base compilation tools (make, libc-dev) |
| `curl` | Command-line HTTP client |
| `fonts-symbola` | Unicode symbol font (required for Claude Code icons) |
| `g++` | GNU C++ compiler |
| `gcc` | GNU C compiler |
| `git` | Version control system, from the [git-core PPA](https://launchpad.net/~git-core/+archive/ubuntu/ppa), which follows upstream releases; Ubuntu's own stays at the version the release shipped with (2.43 on 24.04) |
| `git-lfs` | Git Large File Storage, for repos that keep binaries in LFS. Its filter is in the tracked `.gitconfig`, so `git lfs install` has nothing left to change |
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
| [difftastic](https://github.com/Wilfred/difftastic) | latest | Diffs by syntax rather than by line: `git dft`, and a second diff view in lazygit, where `\|` switches (GitHub release) |
| [lazygit](https://github.com/jesseduffield/lazygit) | latest | Terminal UI for git |
| [glab](https://gitlab.com/gitlab-org/cli) | latest | GitLab CLI — merge requests, pipelines and issues from the terminal (gitlab.com `.deb`; replaces Ubuntu's much older apt package). Log in once per host with `glab auth login --hostname <your GitLab host>`; the token stays in `~/.config/glab-cli/`, which is not tracked |
| [gh](https://cli.github.com/) | latest | GitHub CLI — pull requests, actions and issues from the terminal (release `.deb`, checked against its sha256; replaces Ubuntu's older apt package). Installed next to glab, so either forge works; log in with `gh auth login` |
| [bat](https://github.com/sharkdp/bat) | latest | Syntax-highlighted file viewer |
| [fzf](https://github.com/junegunn/fzf) | latest | General-purpose fuzzy finder (GitHub release) |
| [eza](https://github.com/eza-community/eza) | latest | Modern `ls` replacement with icons and git status (GitHub release — not in Ubuntu's apt repos until 23.10+) |
| [ripgrep](https://github.com/BurntSushi/ripgrep) | latest | Fast recursive search used by Telescope's live grep (GitHub release) |
| [fd](https://github.com/sharkdp/fd) | latest | Fast, `.gitignore`-aware file finder used by Telescope and fzf (GitHub release; binary is named `fd` directly, no `fdfind` symlink needed) |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | latest | Smarter `cd` that learns your most-used directories (GitHub release) |
| [direnv](https://direnv.net/) | latest | Loads and unloads a directory's `.envrc` as you `cd` in and out; Powerlevel10k already has a segment for it (GitHub release) |
| [just](https://github.com/casey/just) | latest | Runs a project's recipes (build, flash, test, …) from its `justfile`; Tab completes recipe names (GitHub release) |
| [dust](https://github.com/bootandy/dust) | latest | `du` with a tree and bars, biggest first (GitHub release) |
| [duf](https://github.com/muesli/duf) | latest | `df` as a readable table of disks (GitHub `.deb`) |
| [yazi](https://github.com/sxyazi/yazi) | latest | Terminal file manager with image, PDF and video previews drawn through Kitty's graphics protocol. Start it with `y`, which leaves the shell in the directory you quit in. `Enter` goes into a directory rather than opening it in nvim (the official smart-enter plugin, vendored in `.config/yazi/plugins`) (GitHub release, with its `ya` plugin manager). Colours follow the theme picker: yazi's official flavors, and gruvbox-dark.yazi for Gruvbox |
| [btop](https://github.com/aristocratos/btop) | latest | Interactive process and resource monitor (GitHub release; theme follows the active theme picker, background left transparent) |
| [jq](https://github.com/jqlang/jq) | latest | Command-line JSON processor, required by Claude Code status line (GitHub release) |
| [Bitwarden CLI](https://bitwarden.com/help/cli/) | latest | `bw`, backs the git credential helper for HTTPS remotes — see [Bitwarden for git credentials](git.md#bitwarden-for-git-credentials) (GitHub release `cli-v*`, native zip — no Node needed) |

**Build toolchain**

| Tool | Version | Description |
|---|---|---|
| [CMake](https://cmake.org/) | 4.4.2 | Cross-platform build system generator (GitHub release) |
| [ninja](https://github.com/ninja-build/ninja) | 1.13.2 | Fast build system, used with cmake (GitHub release) |
| [Meson](https://mesonbuild.com/) | latest | Build system for C projects that use it (`uv tool`; apt's is too old for C23 projects, which need ≥ 1.4) |
| [Arm GNU Toolchain](https://gitlab.arm.com/tooling/gnu-toolchains-for-arm) | 15.3.rel1 | Bare-metal `arm-none-eabi-gcc`/`g++`/`gdb`/`objcopy`/etc. cross-toolchain (GitLab generic package — not packaged for apt at all) |
| [LLVM/Clang tools](https://github.com/llvm/llvm-project) | 18.1.8 | `clangd`, `clang-format`, `clang-tidy`, `clang`, `lld` (GitHub release; ~1-2GB download, 7-12GB extracted — only the entry points are symlinked out of the full LLVM tree, on `PATH` for Neovim and the CLI). Change it with `--llvm` — see [Choosing an LLVM version](toolchain.md#choosing-an-llvm-version) |
| [Rust](https://www.rust-lang.org/) | stable | `rustc`, `cargo`, `rustfmt`, `clippy` (official rustup installer; also builds the tree-sitter CLI on glibc < 2.39) |

**Python**

| Tool | Version | Description |
|---|---|---|
| [uv](https://docs.astral.sh/uv/) | latest | Python versions, projects and virtualenvs — replaces pyenv + Poetry (standalone installer, updates itself with `uv self update`; never edits shell rc files). Not pinned: a newer uv reads older projects fine |

**Editor tooling**

| Tool | Version | Description |
|---|---|---|
| [tree-sitter CLI](https://github.com/tree-sitter/tree-sitter) | latest | Compiles Neovim treesitter parsers. Required by nvim-treesitter `main` (needs ≥ 0.26.1; apt ships 0.20.8, so this is a GitHub release) |
| [Ruff](https://github.com/astral-sh/ruff) | 0.16.1 | Python linter/formatter (`uv tool`, on `PATH` for Neovim and the CLI) |
| [basedpyright](https://github.com/DetachHead/basedpyright) | latest | Python type checker (`uv tool`, on `PATH` for Neovim and the CLI) |
| [StyLua](https://github.com/JohnnyMorganz/StyLua) | latest | Lua formatter (GitHub release, on `PATH` for Neovim and the CLI) |
| [lua-language-server](https://github.com/LuaLS/lua-language-server) | latest | Lua language server for Neovim's `lua_ls` (GitHub release, unpacked into `~/.local/share` and linked into `~/.local/bin`; no sudo) |
| [shellcheck](https://www.shellcheck.net/) | latest | Lints shell scripts; `--verify` runs it on `install.sh` and fails on any warning (`uv tool`, from the `shellcheck-py` package) |

**Shell and fonts**

| Tool | Version | Description |
|---|---|---|
| [Oh My Zsh](https://ohmyz.sh/) | latest | Zsh framework |
| [Powerlevel10k](https://github.com/romkatv/powerlevel10k) | pinned commit | Zsh prompt theme |
| FiraCode Nerd Font | latest | Programming ligature font with Nerd Font icons |
| [Maple Mono NL](https://github.com/subframe7536/maple-font) | latest | Cursive italics for kitty, which Fira Code lacks; the build without ligatures, checked against the sha256 its release publishes |

**Applications**

| Tool | Version | Description |
|---|---|---|
| [Kitty](https://sw.kovidgoyal.net/kitty/) | latest | GPU-accelerated terminal |
| [Neovim](https://neovim.io/) | pinned `v0.12.6` | Code editor (release tarball). Pinned, not latest — see [Why Neovim is pinned](neovim.md#why-neovim-is-pinned) |
| [Visual Studio Code](https://code.visualstudio.com/) | latest | Code editor (Microsoft apt repo) |
| [Claude Code](https://claude.ai/code) | latest | Anthropic AI CLI (native installer in `~/.local/bin`; auto-updates, no sudo) |

**Serial ports** — see [Serial ports](serial-ports.md)

| What | Description |
|---|---|
| `dialout` group | Adds you to it, so USB-serial adapters open without sudo or `chmod` |
| `98-ftdi-latency.rules` | Copied into `/etc/udev/rules.d`; sets every FTDI port's latency timer to 1 ms on plug-in |
| `ports` | Lists USB serial ports, watches them being plugged in and out, and shares one on the network (linked into `~/.local/bin`) |
| ser2net | Newest ser2net and gensio built from source into `/usr/local`, with a disabled systemd unit, for `ports share`; also `./install.sh --ser2net` alone |

## Machine-local files

These files are **not** tracked in dotfiles — they are machine-specific and generated during setup:

| File | Purpose |
|---|---|
| `~/.gitconfig.local` | Git name and email for this machine (`--identity` writes them; other keys you add, such as a signing key, are kept) |
| `~/.zshrc.local` | Shell overrides for this machine (copied from a profile template) |
| `~/.ssh/config.local` | SSH hosts for this machine (copied from a profile template), read before the shared `~/.ssh/config` — see [SSH](ssh.md) |
| `~/.zprofile` | Gets one marked line from `install.sh` that puts `~/.local/bin` and kitty on the PATH of the desktop session, which starts through a zsh login shell and never reads `~/.zshrc`. The rest of the file is yours |
| `~/.config/niri/local.kdl` | niri settings for this machine: the keyboard layout (`--niri` copies GNOME's) and monitor positions — see [niri](niri.md#this-machines-settings) |
| `~/.claude/settings.json` | Claude Code settings: your model, effort, theme, permissions. A plain file, **not** a symlink: `install.sh` overlays the repo's stable `.claude/settings.base.json` (env, hooks, status line, plugins) onto it, so changing the model or theme never dirties the repo. Repo keys win; to change a hook, edit the base file and re-run `./install.sh` |

Never put `BW_SESSION` (the unlocked Bitwarden vault key) in either file — see [Bitwarden for git credentials](git.md#bitwarden-for-git-credentials).

Templates for `~/.zshrc.local` live in the repo as `.zshrc.local.personal` and `.zshrc.local.work`, and for `~/.ssh/config.local` as `.ssh/config.local.personal` and `.ssh/config.local.work`. Add shared personal/work shell config there; add truly machine-specific things (API keys, VPN aliases) directly to `~/.zshrc.local`.
