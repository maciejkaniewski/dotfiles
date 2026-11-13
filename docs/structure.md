# Structure

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
│   ├── fuzzel/
│   │   └── {variant}.ini              # niri's launcher, one whole config per theme (fuzzel has no include)
│   ├── lazygit/
│   │   ├── config.yml
│   │   └── {variant}.yml              # Catppuccin/Gruvbox/Dracula theme per variant, merged via LG_CONFIG_FILE
│   ├── mako/
│   │   └── {variant}.conf             # niri's notification daemon, one whole config per theme
│   ├── niri/
│   │   ├── config.kdl                 # the niri session: layout, startup programs, key bindings
│   │   └── {variant}.kdl              # focus ring and overview colours; ~/.config/niri/theme.kdl links to one
│   ├── p10k/
│   │   └── {variant}.zsh              # Catppuccin/Gruvbox/Dracula Powerlevel10k colors per variant
│   ├── swaylock/
│   │   └── {variant}.conf             # niri's lock screen colours
│   ├── waybar/
│   │   ├── config.jsonc               # the niri session's bar: workspaces, window, system readouts
│   │   ├── style.css
│   │   └── {variant}.css              # colour definitions; ~/.config/waybar/theme.css links to one
│   ├── yazi/
│   │   ├── keymap.toml                # Enter goes into a directory (smart-enter)
│   │   ├── {variant}.toml             # the flavor each theme uses; ~/.config/yazi/theme.toml links to one
│   │   ├── flavors/                   # vendored yazi flavors, one per theme, with their licences
│   │   └── plugins/
│   │       └── smart-enter.yazi/      # official plugin, vendored
│   ├── zsh-syntax-highlighting/
│   │   └── {variant}.zsh              # Catppuccin/Gruvbox/Dracula theme per variant
│   └── nvim/
│       ├── init.lua
│       ├── stylua.toml                # 4-space indents for <leader>cf (StyLua defaults to tabs)
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
│               ├── surround.lua
│               ├── telescope.lua
│               ├── theme.lua
│               ├── todo-comments.lua
│               ├── treesitter-context.lua
│               ├── treesitter.lua
│               ├── which-key.lua
│               └── zen-mode.lua
├── .gitconfig
├── .local/
│   └── bin/
│       ├── git-credential-bw          # git credential helper — HTTPS logins from the Bitwarden vault
│       ├── ports                      # list / watch USB serial ports, share one on the network
│       ├── power-menu                 # niri: lock / suspend / log out / reboot / shut down, in fuzzel
│       └── waybar-calendar            # niri: Waybar's date and time, with a Monday-first calendar tooltip
├── .p10k.zsh
├── .ssh/
│   ├── config                         # shared client settings, includes ~/.ssh/config.local first
│   ├── config.local.personal          # ~/.ssh/config.local template, personal profile
│   └── config.local.work              # ~/.ssh/config.local template, work profile (local-network block)
├── .zshrc
├── .zshrc.local.personal
├── .zshrc.local.work
├── docs/                              # the pages README.md links to, one per topic
├── etc/
│   ├── systemd/
│   │   └── system/
│   │       └── ser2net.service        # copied to /etc by --setup / --ser2net: the source-built ser2net, for ports share
│   └── udev/
│       └── rules.d/
│           └── 98-ftdi-latency.rules  # copied to /etc by --setup: 1 ms latency on every FTDI port
├── LICENSE                            # MIT
├── README.md                          # overview and quick start
├── install.sh
└── versions                           # exact tool versions --setup and --niri install
```
