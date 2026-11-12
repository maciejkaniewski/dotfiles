# Build toolchain

The C/C++ toolchain is installed at exact versions, so builds and formatting are the same on every machine. This page covers the pins and how to change them; [installation.md](installation.md) lists everything else `--setup` installs.

## Pinned tool versions

The build toolchain is installed at exact versions, set in [`versions`](../versions) at the repo root, so every machine compiles and formats code the same way. Set them to whatever your CI builds with:

| Tool | Version | Why exact |
|---|---|---|
| LLVM | 18.1.8 | `clang-format`, `clangd`, `clang-tidy`, `lld`. Patch releases of clang-format format the same code differently, so a formatting check only passes when every machine runs the same one |
| clang compiler | 19 | `clang` and `clang++` from apt's `clang-19`, with its libclang for bindgen. Ubuntu 22.04 doesn't package it, so there `--setup` adds the apt.llvm.org repository first. C23 code (`constexpr` objects) needs clang 19 or newer |
| Arm GNU Toolchain | 15.3.rel1 (GCC 15.3.1) | The cross-compiler firmware is built with, fixed so the same source gives the same binary on every machine |
| CMake | 4.4.2 | Fixed with the rest of the toolchain, so a build doesn't change under you |
| Ninja | 1.13.2 | Same reason as CMake |
| Ruff | 0.16.1 | Formatter output changes between releases, and projects set `required-version` to it |

Powerlevel10k and the five Oh My Zsh plugins (zsh-autosuggestions, zsh-syntax-highlighting, fzf-tab, fzf-git, zsh-bat) are pinned in the same file, by commit.

`--setup` installs each one at exactly that version, moving down as well as up, and `--verify` fails when one has drifted. To change one on a single machine, put the same `key=version` line in `~/.config/dotfiles/versions` (untracked) and re-run `./install.sh --setup`; `latest` tracks upstream instead. Tools not in the file always track the newest release.

## Choosing an LLVM version

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
