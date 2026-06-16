# dotfiles

My personal dotfiles — shell prompt, aliases, vim, and tmux config — kept in sync
across machines with a single installer.

## What's inside

```
bash/    bashrc, bash_profile, prompt.bash   (interactive bash + two-line prompt)
zsh/     zshrc, prompt.zsh                    (zsh, prompt matched to bash)
shell/   aliases.sh                           (aliases shared by bash + zsh)
vim/     vimrc                                (sensible defaults, no plugins)
tmux/    tmux.conf                            (C-a prefix, | and - splits)
macos/   hammerspoon/, *.terminal             (reference assets, not auto-installed)
install.sh    bootstrap.sh
```

## Install

On a machine that already has the repo cloned to `~/dotfiles`:

```sh
cd ~/dotfiles && ./install.sh
```

On a brand-new machine, one command does it all (clone + install):

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/BenGNelson/dotfiles/main/bootstrap.sh)
```

The installer is **idempotent** and **non-destructive**:

- It adds a small managed block to `~/.bashrc`, `~/.bash_profile`, `~/.zshrc`,
  `~/.vimrc`, and `~/.tmux.conf` that sources the matching repo file.
- Re-running updates that block in place — it never duplicates.
- The first time it touches a non-empty file, it backs the original up to
  `<file>.dotfiles-bak-<timestamp>`.

Open a new shell afterwards, or run `reload`.

## The prompt

Two lines: the working directory (and git status) on top, the machine name and an
arrow on the bottom:

```
/home/ben (main)
r2d2 ->
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

## Per-machine settings

Anything machine-specific — a custom prompt label, secrets, extra exports — goes
in `~/.config/dotfiles/local.sh`. The installer seeds this file on first run. It
lives **outside** the repo, so it's never tracked and can never dirty git.

## Keeping machines in sync

Pull the latest and re-run the installer in one step:

```sh
dot-update
```

## Aliases

Defined in `shell/aliases.sh` — navigation (`..`, `...`, `dl`, `docs`, `home`),
`ls` variants (`ll`, `la`, `lrth`, `lrtha`), git shortcuts (`gs`, `ga`, `gc`,
`gd`, `gl`, `gp`, `gco`, `gb`), safer `rm`/`cp`/`mv`, plus helpers `mkcd`,
`extract`, `reload`, and `dot-update`.
