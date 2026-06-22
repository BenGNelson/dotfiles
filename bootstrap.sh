#!/usr/bin/env bash
#
# One-shot bootstrap for a brand-new machine: optionally install the tools,
# clone (or update) the dotfiles repo, then run the installer. Designed to be
# piped from curl:
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/BenGNelson/dotfiles/main/bootstrap.sh)
#
# Pass --with-tools to apt-get install git/vim/tmux first (Debian/Ubuntu only,
# needs sudo). Without it, the configs are wired up for whatever is already
# present:
#
#   bash <(curl -fsSL .../bootstrap.sh) --with-tools

set -euo pipefail

REPO_URL="https://github.com/BenGNelson/dotfiles.git"
DEST="$HOME/dotfiles"

# ── Optional: install the tools the configs are written for ──────────────────
if [ "${1:-}" = "--with-tools" ]; then
    if command -v apt-get > /dev/null 2>&1; then
        echo "Installing git, vim, tmux via apt-get ..."
        SUDO=""
        [ "$(id -u)" -ne 0 ] && SUDO="sudo"
        $SUDO apt-get update -qq
        $SUDO apt-get install -y git vim tmux
    else
        echo "--with-tools only supports apt-get (Debian/Ubuntu); install git/vim/tmux yourself." >&2
        exit 1
    fi
fi

if ! command -v git > /dev/null 2>&1; then
    echo "git is required but not installed. Install git (or re-run with --with-tools) and retry." >&2
    exit 1
fi

if [ -d "$DEST/.git" ]; then
    echo "Updating existing repo at $DEST ..."
    git -C "$DEST" pull --ff-only
else
    echo "Cloning $REPO_URL -> $DEST ..."
    git clone "$REPO_URL" "$DEST"
fi

exec "$DEST/install.sh"
