# dotfiles

[![test](https://github.com/BenGNelson/dotfiles/actions/workflows/test.yml/badge.svg)](https://github.com/BenGNelson/dotfiles/actions/workflows/test.yml)

My personal dotfiles — shell prompt, aliases, vim, and tmux config — kept in sync
across machines with a single installer. CI installs them from scratch on Ubuntu,
Debian, Fedora, Arch, and openSUSE on every push, so "works on a fresh machine"
is verified, not hoped for.

## What's inside

```
bash/    bashrc, bash_profile, prompt.bash   (interactive bash + two-line prompt)
zsh/     zshrc, prompt.zsh                    (zsh, prompt matched to bash)
shell/   aliases.sh                           (aliases shared by bash + zsh)
vim/     vimrc                                (sensible defaults, no plugins)
tmux/    tmux.conf                            (C-a prefix, mouse, status bar)
git/     gitconfig                            (aliases + sane defaults; identity stays local)
lib/     install-tools.sh                     (package-manager-agnostic tool install)
macos/   hammerspoon/, *.terminal             (reference assets, not auto-installed)
install.sh    bootstrap.sh    test.sh         (+ .github/workflows/test.yml)
```

## Install

**Requirements:** `git` (for the bootstrap clone and `dot-update`). The shell/tool
configs apply only to what you have installed — bash, and optionally zsh, vim, tmux.

On a machine that already has the repo cloned to `~/dotfiles`:

```sh
cd ~/dotfiles && ./install.sh
```

On a brand-new machine, one command does it all (clone + install):

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/BenGNelson/dotfiles/main/bootstrap.sh)
```

On a bare machine that doesn't even have the tools yet, add `--with-tools` to
install git/vim/tmux first. It detects the package manager (apt/dnf/pacman/zypper),
so it works on Debian/Ubuntu, Fedora, Arch, and openSUSE alike (may use sudo):

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/BenGNelson/dotfiles/main/bootstrap.sh) --with-tools
```

The installer is **idempotent** and **non-destructive**:

- It adds a small managed block to `~/.bashrc`, `~/.bash_profile`, `~/.zshrc`,
  `~/.vimrc`, and `~/.tmux.conf` that sources the matching repo file, and wires
  `git/gitconfig` into `~/.gitconfig` via a native `[include]`.
- Re-running updates that block in place — it never duplicates.
- The first time it touches a non-empty file, it backs the original up to
  `<file>.dotfiles-bak-<timestamp>`.

Open a new shell afterwards, or run `reload`.

To back everything out (strip the managed blocks and the git include — your
backups and `~/.config/dotfiles/` overrides are left alone):

```sh
./install.sh --uninstall
```

### Login shells

`~/.bash_profile` sources `~/.profile` (so a login/SSH shell keeps the distro's
PATH setup, e.g. `~/.local/bin`) and then `~/.bashrc`, loading the config exactly
once. Repo paths are derived from each rc file's own location, so the clone
doesn't have to live at `~/dotfiles`.

## The prompt

Two lines: the working directory (and git status) on top, the machine's hostname
and an arrow on the bottom (`mybox` below stands in for whatever the machine is
actually called):

```
~/projects (main)
mybox ->
```

The git segment shows `branch`, a `*` when dirty, and `↑`/`↓` when ahead/behind
the upstream. It turns red when dirty or behind, yellow otherwise.

### The machine name (no more per-machine edits)

The bottom-line name defaults to the machine's **live hostname**, so it's correct
on every machine with zero edits and nothing to commit. To show a custom label
instead, set it in the untracked local file (see below):

```sh
export DOTFILES_LABEL="deathstar"
```

## git

`git/gitconfig` carries shortcuts (`git st`, `co`, `br`, `ci`, `lg`, …) and sane
defaults (`init.defaultBranch=main`, `pull.ff=only`, `push.autoSetupRemote`,
`fetch.prune`). It's wired into `~/.gitconfig` with a native `[include]`, so it
stacks on top of whatever is already there rather than replacing it.

Your **identity** (name/email) deliberately lives in the untracked
`~/.config/dotfiles/gitconfig.local`, not in the repo — set it once per machine:

```sh
git config --file ~/.config/dotfiles/gitconfig.local user.name  "Your Name"
git config --file ~/.config/dotfiles/gitconfig.local user.email "you@example.com"
```

## Per-machine settings

Anything machine-specific — a custom prompt label, secrets, extra exports — goes
in `~/.config/dotfiles/local.sh` (shell) or `~/.config/dotfiles/gitconfig.local`
(git). The installer seeds both on first run. They live **outside** the repo, so
they're never tracked and can never dirty git.

## Keeping machines in sync

Pull the latest and re-run the installer in one step:

```sh
dot-update
```

## Testing

`test.sh` spins up clean containers across a matrix of distros — Ubuntu 24.04 &
22.04, Debian 12, Fedora, Arch, and openSUSE (the four major package-manager
families: apt, dnf, pacman, zypper) — installs the dotfiles into each like a
brand-new machine, and asserts the result is correct, idempotent (install runs
twice), and reversible (`--uninstall`). The in-container dependency install goes
through `lib/install-tools.sh`, so each run also exercises the cross-distro tool
installer. Requires Docker; nothing touches the host:

```sh
./test.sh                     # full matrix
./test.sh ubuntu:24.04        # a single image
./test.sh debian:12 fedora:latest   # a chosen subset
```

The same matrix runs in CI (`.github/workflows/test.yml`) on every push.

## tmux

Prefix is `C-a` (not the default `C-b`). Mouse is on (click panes, drag borders,
scroll history), with a status bar showing session, windows, host, and clock.

The only commands you actually need:

```sh
tmux new -s work     # start a named session 'work'
#   C-a d            # detach — leave it running, return to your normal shell
tmux attach -t work  # reattach later (survives SSH drops / closing the laptop)
tmux ls              # list running sessions
```

Inside a session: `C-a |` and `C-a -` split panes, `C-a h/j/k/l` move between
them, `C-a r` reloads the config.

## Aliases

Defined in `shell/aliases.sh` — navigation (`..`, `...`, `dl`, `docs`, `home`),
`ls` variants (`ll`, `la`, `lrth`, `lrtha`), git shortcuts (`gs`, `ga`, `gc`,
`gd`, `gl`, `gp`, `gco`, `gb`), safer `rm`/`cp`/`mv`, plus helpers `mkcd`,
`extract`, `reload`, and `dot-update`.
