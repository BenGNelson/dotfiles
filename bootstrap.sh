#!/usr/bin/env bash
#
# One-shot bootstrap for a brand-new machine: optionally install the tools,
# clone (or update) the dotfiles repo, then run the installer. Designed to be
# piped from curl:
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/BenGNelson/dotfiles/main/bootstrap.sh)
#
# Pass --with-tools to install git/vim/tmux first (apt/dnf/pacman/zypper, may
# use sudo). Without it, the configs are wired up for whatever is already
# present:
#
#   bash <(curl -fsSL .../bootstrap.sh) --with-tools

set -euo pipefail

REPO_URL="https://github.com/BenGNelson/dotfiles.git"
DEST="$HOME/dotfiles"
WITH_TOOLS=""
[ "${1:-}" = "--with-tools" ] && WITH_TOOLS=1

# git must exist before we can clone the repo (which is where the shared
# install-tools helper lives). If --with-tools was asked for, install just git
# here with a minimal package-manager probe; the full tool set is installed via
# lib/install-tools.sh once the repo is present.
if ! command -v git > /dev/null 2>&1; then
    if [ -n "$WITH_TOOLS" ]; then
        echo "Installing git ..."
        SUDO=""
        [ "$(id -u)" -ne 0 ] && command -v sudo > /dev/null 2>&1 && SUDO="sudo"
        if command -v apt-get > /dev/null 2>&1; then
            $SUDO apt-get update -qq && DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y git
        elif command -v dnf > /dev/null 2>&1; then $SUDO dnf install -y git
        elif command -v pacman > /dev/null 2>&1; then $SUDO pacman -Sy --noconfirm git
        elif command -v zypper > /dev/null 2>&1; then $SUDO zypper --non-interactive install git
        else
            echo "No supported package manager found; install git yourself and re-run." >&2
            exit 1
        fi
    else
        echo "git is required but not installed. Install git (or re-run with --with-tools) and retry." >&2
        exit 1
    fi
fi

if [ -d "$DEST/.git" ]; then
    echo "Updating existing repo at $DEST ..."
    git -C "$DEST" pull --ff-only
else
    echo "Cloning $REPO_URL -> $DEST ..."
    git clone "$REPO_URL" "$DEST"
fi

# Now the repo (and the shared helper) exists — install the rest of the tools.
if [ -n "$WITH_TOOLS" ]; then
    # shellcheck source=lib/install-tools.sh
    . "$DEST/lib/install-tools.sh"
    dotfiles_install_tools git vim tmux
fi

exec "$DEST/install.sh"
