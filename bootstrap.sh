#!/usr/bin/env bash
#
# One-shot bootstrap for a brand-new machine: clone (or update) the dotfiles
# repo, then run the installer. Designed to be piped from curl:
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/BenGNelson/dotfiles/main/bootstrap.sh)

set -euo pipefail

REPO_URL="https://github.com/BenGNelson/dotfiles.git"
DEST="$HOME/dotfiles"

if ! command -v git > /dev/null 2>&1; then
    echo "git is required but not installed. Install git and re-run." >&2
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
