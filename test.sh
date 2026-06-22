#!/usr/bin/env bash
#
# Fresh-machine smoke test across a matrix of Linux distros. For each image it
# spins up a clean container, installs the dotfiles exactly like a new machine
# would, and asserts the result is correct, idempotent (install runs twice), and
# reversible (--uninstall). The dependency install inside each container goes
# through lib/install-tools.sh, so this also exercises the cross-distro
# (apt/dnf/pacman/zypper) tool installer. A second pass per image then drives the
# real curl-pipe entry point, bootstrap.sh --with-tools, end to end (inline git
# probe -> clone -> tools -> install.sh). Requires Docker; nothing is installed
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

# A second, fresh-container pass that drives the real entry point — bootstrap.sh
# --with-tools — end to end. On a clean image with no ~/dotfiles (and, on most
# base images, no git) this exercises the one path the install test above skips:
# bootstrap's own inline git probe, the clone, the install-tools call, and the
# hand-off to install.sh — i.e. exactly what a curl-piped new machine runs.
read -r -d '' BOOTSTRAP_SCRIPT <<'BOOTSTRAP' || true
set -euo pipefail

fail() { echo "  ✗ $1"; exit 1; }
pass() { echo "  ✓ $1"; }

# Point bootstrap at the mounted repo so it clones locally — hermetic, no
# network. safe.directory '*' avoids git's dubious-ownership refusal when the
# mount is owned by a different uid than the (root) container user. Writing the
# file works even before git is installed (bootstrap's probe installs it).
printf '[safe]\n\tdirectory = *\n' > ~/.gitconfig

if command -v git > /dev/null 2>&1; then
    echo "  (git already on this image — bootstrap's inline git probe is skipped)"
else
    echo "  (no git — bootstrap's inline git install runs first)"
fi

REPO_URL=/repo bash /repo/bootstrap.sh --with-tools

for t in git vim tmux; do
    command -v "$t" > /dev/null 2>&1 || fail "$t not installed by bootstrap --with-tools"
done
pass "bootstrap --with-tools installed the tool set (git, vim, tmux)"

[ -d ~/dotfiles/.git ] || fail "bootstrap did not clone the repo to ~/dotfiles"
pass "repo cloned to ~/dotfiles"

grep -qF ">>> dotfiles >>>" ~/.bashrc 2>/dev/null \
    || fail "bootstrap did not run install.sh (no managed block in ~/.bashrc)"
pass "bootstrap ran install.sh (managed block present)"

echo "BOOTSTRAP OK"
BOOTSTRAP

# ── Run the matrix ───────────────────────────────────────────────────────────
declare -a RESULTS
overall=0

# Pipe a script into a throwaway container for one image.
run_in() {  # run_in <image> <script>
    printf '%s' "$2" | docker run --rm -i \
        -v "$REPO":/repo:ro \
        -e DEBIAN_FRONTEND=noninteractive \
        "$1" bash
}

for image in "${IMAGES[@]}"; do
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  $image"
    echo "════════════════════════════════════════════════════════════════"
    ok=1
    echo "── install + assertions ────────────────────────────────────────"
    run_in "$image" "$CONTAINER_SCRIPT" || ok=0
    echo "── bootstrap --with-tools (end-to-end) ─────────────────────────"
    run_in "$image" "$BOOTSTRAP_SCRIPT" || ok=0
    if [ "$ok" -eq 1 ]; then
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
