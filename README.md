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

A Linux development environment for embedded C/C++ and Python, set up by one script and themed the same in every tool. Pick [Catppuccin](https://github.com/catppuccin/catppuccin) (Frappé / Macchiato / Mocha), [Gruvbox](https://gruvbox.org/) Dark or [Dracula](https://draculatheme.com/) at setup. Tested on a fresh Ubuntu 26.04 install and used daily on 24.04.

## Stack

| Category | Tool |
|---|---|
| Terminal | [Kitty](https://sw.kovidgoyal.net/kitty/) |
| Shell | [Zsh](https://www.zsh.org/) + [Oh My Zsh](https://ohmyz.sh/) + [Powerlevel10k](https://github.com/romkatv/powerlevel10k) |
| Editor | [Neovim](https://neovim.io/) with [lazy.nvim](https://github.com/folke/lazy.nvim), [VS Code](https://code.visualstudio.com/) |
| AI | [Claude Code](https://claude.ai/code) |
| Git | [delta](https://github.com/dandavison/delta), [difftastic](https://github.com/Wilfred/difftastic), [lazygit](https://github.com/jesseduffield/lazygit), [gh](https://cli.github.com/), [glab](https://gitlab.com/gitlab-org/cli) |
| Search and files | [fzf](https://github.com/junegunn/fzf), [ripgrep](https://github.com/BurntSushi/ripgrep), [fd](https://github.com/sharkdp/fd), [bat](https://github.com/sharkdp/bat), [eza](https://github.com/eza-community/eza), [zoxide](https://github.com/ajeetdsouza/zoxide), [yazi](https://github.com/sxyazi/yazi) |
| Build | LLVM/clang, Arm GNU Toolchain, CMake, Ninja, Meson, Rust, [just](https://github.com/casey/just) |
| Python | [uv](https://docs.astral.sh/uv/), [Ruff](https://github.com/astral-sh/ruff), [basedpyright](https://github.com/DetachHead/basedpyright) |
| Desktop | GNOME, or the [niri](https://github.com/niri-wm/niri) scrolling-tiling session with [Waybar](https://github.com/Alexays/Waybar), opt-in |
| Fonts | [FiraCode Nerd Font](https://github.com/ryanoasis/nerd-fonts) (terminal and editors, with ligatures), [Maple Mono NL](https://github.com/subframe7536/maple-font) (cursive italics in kitty) |

## Quick start

```bash
git clone https://github.com/maciejkaniewski/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh -s        # full setup on a fresh machine (asks for sudo once)
```

Then log out and back in, so the session starts with zsh, and open kitty. Near the end, setup asks for your git name and email and for a personal or work profile; nothing in the repo is tied to one person.

| Command | What it does |
|---|---|
| `./install.sh -s` | Full setup: packages, tools, shell, fonts, configs and theme, then `--verify` |
| `./install.sh` | Link the configs only |
| `./install.sh -v` | Check that the installed toolchain works (no sudo) |
| `./install.sh --theme` | Pick or re-apply the colour theme |
| `./install.sh --identity` | Set your git name and email, and the personal or work profile |
| `./install.sh --niri` | Add the niri tiling session to the login screen (`--setup` also offers it) |
| `./install.sh --llvm [version]` | Show or change the LLVM version |
| `./install.sh -c` | Remove the config symlinks |

## Documentation

| Page | What's in it |
|---|---|
| [Installation](docs/installation.md) | Every flag, everything `--setup` installs, the machine-local files |
| [Build toolchain](docs/toolchain.md) | The pinned versions and how to switch LLVM |
| [Neovim](docs/neovim.md) | Plugins, keymaps, snippets, editing alongside Claude Code, why Neovim is pinned |
| [niri](docs/niri.md) | The tiling session: key bindings, Waybar, themes, per-machine monitors |
| [Kitty](docs/kitty.md) | Status bar, fonts, key bindings |
| [Shell](docs/shell.md) | Zsh plugins, prompt, history, completion and helper functions |
| [Git](docs/git.md) | Git defaults, lazygit, Bitwarden for HTTPS credentials |
| [SSH](docs/ssh.md) | Per-profile hosts, host completion, kitty's ssh kitten |
| [Serial ports](docs/serial-ports.md) | `ports`, FTDI latency, sharing an adapter over the network |
| [Structure](docs/structure.md) | What each file in the repo is for |

## License

[MIT](LICENSE) — fork it, copy from it, change it. The theme files under `.config/` (Catppuccin, Gruvbox, Dracula) come from their upstream projects, which are MIT-licensed too.
