# Git

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
| `filter.lfs` | [Git LFS](https://git-lfs.com/) on for every repo (installed by `--setup`). This is the block `git lfs install` writes, kept in the repo so running it doesn't modify the tracked file |

Name and email are set per-machine in `~/.gitconfig.local` (see [Machine-local files](installation.md#machine-local-files)).

**difftastic** — `git dft` is `git diff` through [difftastic](https://github.com/Wilfred/difftastic), which compares syntax trees, so a moved argument or a re-wrapped expression shows as what changed rather than as two whole lines. It takes `git diff`'s arguments (`git dft --staged`, `git dft HEAD~1`). In lazygit, `|` switches the diff panel between delta and difftastic. delta stays the default pager everywhere.

**lazygit** — theme (Catppuccin via [catppuccin/lazygit](https://github.com/catppuccin/lazygit), blue accent; Gruvbox and [dracula/lazygit](https://github.com/dracula/lazygit) adapted to match) follows the active theme picker. `config.yml` holds everything except the theme; each variant's colors live in a separate `{variant}.yml` and are merged in via the `LG_CONFIG_FILE` env var (set in `.zshrc`) rather than baked into `config.yml` directly. Diffs are rendered by delta (same theme and line numbers as `git diff`), with Nerd Font icons. Machine-local settings, such as `services:` for a self-hosted GitLab, go in `~/.config/lazygit/config.local.yml`, which `.zshrc` appends to `LG_CONFIG_FILE` when it exists.

## Bitwarden for git credentials

For HTTPS remotes (a self-hosted GitLab, say), git asks the Bitwarden vault for the login instead of prompting. `credential.helper = bw` runs `.local/bin/git-credential-bw` (linked into `~/.local/bin` by `install.sh`). SSH remotes are unaffected.

`credential.helper = bw` is in the tracked `.gitconfig`, so it is on for every machine. It does nothing until you run `bwu`, and only acts on `http(s)` remotes.

**One-time setup, per machine**

1. `./install.sh -s` installs `bw` (or grab it from [bitwarden.com/help/cli](https://bitwarden.com/help/cli/)).
2. Self-hosted or EU server? Point the CLI at it first: `bw config server https://vault.bitwarden.eu` — a per-machine setting, so no dotfiles entry.
3. In Bitwarden (app, browser or web vault), create one **Login** item per GitLab host:
   - **Name**: `git: gitlab.example.com` — the `git:` prefix is what separates it from your ordinary web login for the same site
   - **URI**: the host, e.g. `https://gitlab.example.com`
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
| You ssh in from your own machine | `ssh -A <host>`, then `git clone git@gitlab.example.com:<group>/<repo>.git` — see agent forwarding below |
| You must clone over HTTPS | `bwu` and `bwcp gitlab.example.com` on your machine; on the server `git -c credential.helper= clone https://…`, type your username and paste the token at `Password:` |
| No laptop and no browser | Put the `bw` binary on the server (`bw-linux-arm64-<version>.zip` for a Jetson, from [bitwarden/clients releases](https://github.com/bitwarden/clients/releases?q=cli-v)), `bw login`, `export BW_SESSION=$(bw unlock --raw)`, then clone with an inline helper (below), and `bw logout` afterwards — it removes the cached vault |

```bash
git -c credential.helper='!f() { [ "$1" = get ] && printf "username=%s\npassword=%s\n" "<gitlab-user>" "$(bw get password "git: gitlab.example.com")"; }; f' \
    clone https://gitlab.example.com/<group>/<repo>.git
```

`-c credential.helper=` (empty) clears any helper the machine has, so nothing is remembered. Never put the token in the clone URL: it ends up in `.git/config`, shell history and `ps`. For production hosts use a separate token: `read_repository` only, expiring after about a day.

**Agent forwarding (`ssh -A`)** lets the remote machine use the key held by your local ssh agent without ever receiving it: GitLab's challenge travels back through your ssh connection and your agent answers it.

- Needs the key loaded locally (`ssh-add -l` lists it; otherwise `ssh-add ~/.ssh/<key>`), its public half on your GitLab account, a route from the remote machine to GitLab, and a server that allows forwarding (the default; hardened hosts may not).
- Check on the remote: `ssh-add -l` should list your key, and `ssh -T git@gitlab.example.com` greets you by name.
- It exists only while the connection is open. After `exit` nothing is left behind and the clone keeps working; pulling or pushing over SSH needs another `-A` session.
- With `kitten ssh`, "the connection" is kitty's shared master, which stays open after `exit` until kitty quits, and a later `-A` login reuses a master opened without it (`ssh-add -l` then finds no agent). `.config/kitty/ssh.conf` turns sharing off for `*.local` and `192.168.*` hosts; add other hosts you forward to there. To close a master now: `ssh -O exit -o ControlPath=/run/user/$UID/kssh-<kitty-pid>-%C <user>@<host>`.
- While connected, root on the remote machine can use your agent to authenticate as you (it can't copy the key). Use it only on hosts you trust, and enable it per host (`ForwardAgent yes` under that `Host` in `~/.ssh/config`), never for `Host *`.

**What it will and won't do**

- **Read-only.** `store` and `erase` do nothing, so git never writes a token into the vault or a plaintext file, and a rejected token is not remembered.
- **Locked vault, no match, or an expired session:** prints a one-line reason to stderr and git falls back to its normal prompt.
- **Exact host match.** Bitwarden's default URI matching compares the base domain, so `gitlab.example.com` would also match every other `example.com` item (SSO, Jira). The helper only accepts items whose URI host equals the requested host.
- **Several items for the same host.** Your ordinary web login for the site shares the host with the token item, so this is normal. Name the token item starting with `git:` (e.g. `git: github.com`) and it wins. With no `git:` item, or two of them (personal and work account), it refuses to guess and prompts. Tell git which one per host, and it picks by username:

  ```bash
  git config --global credential.https://gitlab.example.com.username <username>    # or set it per repo without --global
  ```
- **Never use the master password as an argument** (`bw unlock <password>`): it lands in shell history and `ps`.

**Check it**

```bash
bwu
printf 'protocol=https\nhost=gitlab.example.com\n\n' | git credential fill   # prints the stored username and token
bwl
printf 'protocol=https\nhost=gitlab.example.com\n\n' | git credential fill   # locked: says so, then asks for a username
```

Rotating the token: edit the Bitwarden item. The next `bwu` runs `bw sync`, which picks the change up.
