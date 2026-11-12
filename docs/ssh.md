# SSH

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
forwarding under [Bitwarden for git credentials](git.md#bitwarden-for-git-credentials)),
so every login authenticates on its own. Run `ssh-copy-id <host>` once per
machine and that is your key instead of a password.

| Task | How |
|---|---|
| Copy a file during a `kitten ssh` session, without a second login | On the remote: `kitten transfer <remote file> <local dir>`, or `kitten transfer --direction=upload <local file> <remote dir>`. Give local paths in full: the remote shell expands `~` to the remote home |
| Kill a frozen session | `Enter`, then `~.` |
| A machine was reflashed ("REMOTE HOST IDENTIFICATION HAS CHANGED") | `ssh-keygen -R <host>`, then log in again |
