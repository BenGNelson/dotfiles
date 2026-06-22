#!/usr/bin/env bash
#
# Fresh-machine smoke test: spin up a clean ubuntu:24.04 container, install the
# dotfiles into it exactly like a new machine would, and assert that the result
# is correct, idempotent, and reversible. Requires Docker; nothing is installed
# on the host.
#
#   ./test.sh

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="${TEST_IMAGE:-ubuntu:24.04}"

if ! command -v docker > /dev/null 2>&1; then
    echo "docker is required to run this test." >&2
    exit 1
fi

echo "Running dotfiles smoke test in $IMAGE ..."

# The repo is mounted read-only; everything below runs inside the container.
docker run --rm -i \
    -v "$REPO":/repo:ro \
    -e DEBIAN_FRONTEND=noninteractive \
    "$IMAGE" bash <<'CONTAINER'
set -euo pipefail

fail() { echo "  ✗ $1"; exit 1; }
pass() { echo "  ✓ $1"; }

# git for the [include] wiring; zsh to verify the zsh config loads too.
apt-get update -qq && apt-get install -y -qq git zsh > /dev/null

# Make the home dir look like a stock Ubuntu account: a ~/.profile that adds
# ~/.local/bin to PATH and sources ~/.bashrc. This is the exact arrangement the
# bash_profile fix has to cope with (login shells read .profile, which pulls in
# .bashrc — so our config must load once, not twice).
cat > ~/.profile <<'EOF'
# ~/.profile — Ubuntu-style
if [ -n "$BASH_VERSION" ] && [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi
EOF

# Copy the read-only repo to a writable location, like a real clone would land.
cp -r /repo ~/dotfiles

echo "== install (first run) =="
~/dotfiles/install.sh

echo "== install (second run — must be idempotent) =="
~/dotfiles/install.sh

echo "== assertions =="

# Exactly one managed block per file (no duplication on re-run).
for f in ~/.bashrc ~/.bash_profile ~/.zshrc ~/.vimrc ~/.tmux.conf; do
    n=$(grep -cF ">>> dotfiles >>>" "$f" 2>/dev/null || echo 0)
    [ "$n" -eq 1 ] || fail "$f has $n managed blocks (expected 1)"
done
pass "each rc file has exactly one managed block"

# A login interactive shell (the SSH case) loads the config: aliases defined,
# PATH has ~/.local/bin.
out=$(bash -lic 'type ll >/dev/null 2>&1 && echo ALIAS_OK; case ":$PATH:" in *":$HOME/.local/bin:"*) echo PATH_OK;; esac' 2>/dev/null)
[[ "$out" == *ALIAS_OK* ]] || fail "login shell did not load aliases (ll)"
[[ "$out" == *PATH_OK* ]]  || fail "login shell PATH is missing ~/.local/bin"
pass "login shell loads aliases and PATH"

# An interactive non-login shell (desktop terminal) loads the config too.
out=$(bash -ic 'type ll >/dev/null 2>&1 && echo OK' 2>/dev/null)
[[ "$out" == *OK* ]] || fail "interactive shell did not load aliases"
pass "interactive shell loads aliases"

# zsh: the config loads, DOTFILES_DIR resolves from the file's own location,
# aliases are defined, and ~/.local/bin is on PATH.
out=$(zsh -ic 'echo "DIR=$DOTFILES_DIR"; (( $+aliases[ll] )) && echo ALIAS_OK; [[ ":$PATH:" == *":$HOME/.local/bin:"* ]] && echo PATH_OK' 2>/dev/null)
[[ "$out" == *"DIR=$HOME/dotfiles"* ]] || fail "zsh DOTFILES_DIR misresolved (got: $out)"
[[ "$out" == *ALIAS_OK* ]] || fail "zsh did not load aliases (ll)"
[[ "$out" == *PATH_OK* ]]  || fail "zsh PATH is missing ~/.local/bin"
pass "zsh loads config, resolves repo dir, aliases + PATH"

# The login-shell fix: with a stock ~/.profile that sources ~/.bashrc, our
# config must load EXACTLY once (the sentinel stops bash_profile re-sourcing).
out=$(bash -lic 'echo "${_DOTFILES_LOADED:-unset}"' 2>/dev/null)
[[ "$out" == "1" ]] || fail "config loaded $out time(s) in login shell (expected exactly 1 — double-source?)"
pass "login-shell config loads exactly once (no double-source)"

# Git include wired in and the repo aliases resolve through it.
git config --global --get-all include.path | grep -qxF "$HOME/dotfiles/git/gitconfig" \
    || fail "git include.path not wired in"
[ "$(git config --get alias.lg)" = "log --oneline --graph --decorate" ] \
    || fail "git alias from repo gitconfig not visible"
pass "git include wired in and aliases resolve"

# Untracked per-machine override files were seeded.
[ -f ~/.config/dotfiles/local.sh ]        || fail "local.sh not seeded"
[ -f ~/.config/dotfiles/gitconfig.local ] || fail "gitconfig.local not seeded"
pass "per-machine override files seeded"

echo "== uninstall =="
~/dotfiles/install.sh --uninstall
for f in ~/.bashrc ~/.bash_profile ~/.zshrc ~/.vimrc ~/.tmux.conf; do
    grep -qF ">>> dotfiles >>>" "$f" 2>/dev/null && fail "$f still has a managed block after uninstall"
done
git config --global --get-all include.path 2>/dev/null | grep -qxF "$HOME/dotfiles/git/gitconfig" \
    && fail "git include still present after uninstall"
pass "uninstall removed all managed blocks and the git include"

echo ""
echo "ALL CHECKS PASSED"
CONTAINER

echo "Smoke test complete."
