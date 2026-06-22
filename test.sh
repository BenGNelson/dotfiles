#!/usr/bin/env bash
#
# Fresh-machine smoke test across a matrix of Linux distros. For each image it
# spins up a clean container, installs the dotfiles exactly like a new machine
# would, and asserts the result is correct, idempotent (install runs twice), and
# reversible (--uninstall). The dependency install inside each container goes
# through lib/install-tools.sh, so this also exercises the cross-distro
# (apt/dnf/pacman/zypper) tool installer. Requires Docker; nothing is installed
# on the host.
#
#   ./test.sh                       # run the full distro matrix
#   ./test.sh ubuntu:24.04          # run a single image
#   ./test.sh debian:12 fedora:latest   # run a chosen subset

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default matrix: the four mainstream package-manager families.
DEFAULT_IMAGES=(
    ubuntu:24.04        # apt
    ubuntu:22.04        # apt
    debian:12           # apt
    fedora:latest       # dnf
    archlinux:latest    # pacman
    opensuse/leap:15.6  # zypper
)

if [ "$#" -gt 0 ]; then
    IMAGES=("$@")
else
    IMAGES=("${DEFAULT_IMAGES[@]}")
fi

if ! command -v docker > /dev/null 2>&1; then
    echo "docker is required to run this test." >&2
    exit 1
fi

# The assertions that run inside each container. Kept in a variable so it can be
# piped to several images. Single-quoted heredoc: nothing expands on the host.
read -r -d '' CONTAINER_SCRIPT <<'CONTAINER' || true
set -euo pipefail

fail() { echo "  ✗ $1"; exit 1; }
pass() { echo "  ✓ $1"; }

# Copy the read-only repo to a writable location, like a real clone would land.
cp -r /repo ~/dotfiles

# Install the test's own dependencies (git for the [include] wiring, zsh to
# verify the zsh config) THROUGH the shared cross-distro helper — so this step
# is itself a test of lib/install-tools.sh on this distro.
. ~/dotfiles/lib/install-tools.sh
dotfiles_install_tools git zsh > /dev/null

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

echo "ALL CHECKS PASSED"
CONTAINER

# ── Run the matrix ───────────────────────────────────────────────────────────
declare -a RESULTS
overall=0

for image in "${IMAGES[@]}"; do
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  $image"
    echo "════════════════════════════════════════════════════════════════"
    if printf '%s' "$CONTAINER_SCRIPT" | docker run --rm -i \
        -v "$REPO":/repo:ro \
        -e DEBIAN_FRONTEND=noninteractive \
        "$image" bash; then
        RESULTS+=("PASS  $image")
    else
        RESULTS+=("FAIL  $image")
        overall=1
    fi
done

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  Summary"
echo "════════════════════════════════════════════════════════════════"
for r in "${RESULTS[@]}"; do
    echo "  $r"
done

if [ "$overall" -eq 0 ]; then
    echo ""
    echo "All ${#IMAGES[@]} image(s) passed."
else
    echo ""
    echo "Some images failed." >&2
fi
exit "$overall"
