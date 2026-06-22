#!/usr/bin/env bash
#
# Idempotent dotfiles installer.
#
# For each target rc file (~/.bashrc, ~/.zshrc, ...), this drops a small managed
# block that sources the matching file in this repo:
#
#     # >>> dotfiles >>>
#     source ~/dotfiles/bash/bashrc
#     # <<< dotfiles <<<
#
# Re-running updates the block in place (never duplicates). The original file is
# backed up once, the first time a block is added. Per-machine settings live in
# the untracked ~/.config/dotfiles/local.sh — so nothing here ever dirties git.
#
# Git config is wired in differently: an [include] entry in ~/.gitconfig points
# at git/gitconfig (git has no comment syntax for a managed block, but native
# includes are the idiomatic equivalent).
#
# Usage:
#   ./install.sh              install / update
#   ./install.sh --uninstall  remove every managed block + the git include

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The (target_file, source_path, comment_char) set this installer manages. Vim
# needs '"' as its comment char or it errors on the marker lines (E488).
TARGETS=(
    "$HOME/.bashrc|$REPO/bash/bashrc|#"
    "$HOME/.bash_profile|$REPO/bash/bash_profile|#"
    "$HOME/.zshrc|$REPO/zsh/zshrc|#"
    "$HOME/.vimrc|$REPO/vim/vimrc|\""
    "$HOME/.tmux.conf|$REPO/tmux/tmux.conf|#"
)

GITCONFIG="$HOME/.gitconfig"
GIT_INCLUDE="$REPO/git/gitconfig"

# ensure_block <target_file> <source_path> [comment_char]
# Idempotently install/update the managed block in <target_file>.
ensure_block() {
    local target="$1" src="$2" c="${3:-#}"
    local begin="$c >>> dotfiles >>>"
    local end="$c <<< dotfiles <<<"
    local block
    block=$(printf '%s\n%s managed by ~/dotfiles/install.sh — edit the repo, not this block\nsource %s\n%s' \
        "$begin" "$c" "$src" "$end")

    if [ -f "$target" ] && grep -qF "$begin" "$target"; then
        # Block exists — replace everything between the markers (inclusive).
        local tmp
        tmp=$(mktemp)
        awk -v b="$begin" -v e="$end" -v repl="$block" '
            $0==b {print repl; skip=1; next}
            $0==e {skip=0; next}
            !skip {print}
        ' "$target" > "$tmp"
        mv "$tmp" "$target"
        echo "  updated  $target"
    else
        # No block yet — back up an existing non-empty file, then append.
        if [ -s "$target" ]; then
            local bak="${target}.dotfiles-bak-$(date +%Y%m%d%H%M%S)"
            cp "$target" "$bak"
            echo "  backed up $target -> $bak"
        fi
        printf '\n%s\n' "$block" >> "$target"
        echo "  linked   $target -> $src"
    fi
}

# remove_block <target_file> [comment_char] — strip the managed block if present.
remove_block() {
    local target="$1" c="${2:-#}"
    local begin="$c >>> dotfiles >>>"
    local end="$c <<< dotfiles <<<"
    [ -f "$target" ] && grep -qF "$begin" "$target" || return 0
    local tmp
    tmp=$(mktemp)
    awk -v b="$begin" -v e="$end" '
        $0==b {skip=1; next}
        $0==e {skip=0; next}
        !skip {print}
    ' "$target" > "$tmp"
    mv "$tmp" "$target"
    echo "  unlinked $target"
}

# ── Uninstall ────────────────────────────────────────────────────────────────
if [ "${1:-}" = "--uninstall" ]; then
    echo "Removing dotfiles managed blocks ..."
    for entry in "${TARGETS[@]}"; do
        IFS='|' read -r target src c <<< "$entry"
        remove_block "$target" "$c"
    done
    if command -v git > /dev/null 2>&1 \
        && git config --global --get-all include.path 2>/dev/null | grep -qxF "$GIT_INCLUDE"; then
        # --fixed-value (git 2.30+) removes the matching entry without treating
        # the path as a regex.
        git config --global --fixed-value --unset-all include.path "$GIT_INCLUDE"
        echo "  removed  git include -> $GIT_INCLUDE"
    fi
    echo "Done. Your ~/.config/dotfiles/ overrides and *.dotfiles-bak-* backups were left in place."
    exit 0
fi

# ── Install ──────────────────────────────────────────────────────────────────
echo "Installing dotfiles from $REPO ..."

for entry in "${TARGETS[@]}"; do
    IFS='|' read -r target src c <<< "$entry"
    ensure_block "$target" "$src" "$c"
done

# Git: add an [include] pointing at the repo's gitconfig (idempotent).
if command -v git > /dev/null 2>&1; then
    if git config --global --get-all include.path 2>/dev/null | grep -qxF "$GIT_INCLUDE"; then
        echo "  kept     git include -> $GIT_INCLUDE"
    else
        git config --global --add include.path "$GIT_INCLUDE"
        echo "  added    git include -> $GIT_INCLUDE"
    fi
else
    echo "  skipped  git include (git not installed)"
fi

# Seed the untracked per-machine override file (never overwrite an existing one).
LOCAL_DIR="$HOME/.config/dotfiles"
LOCAL_FILE="$LOCAL_DIR/local.sh"
mkdir -p "$LOCAL_DIR"
if [ ! -f "$LOCAL_FILE" ]; then
    cat > "$LOCAL_FILE" <<'EOF'
# Per-machine, untracked overrides. Safe place for secrets and machine-specific
# tweaks — this file is NOT part of the dotfiles git repo.
#
# Override the name shown on the prompt's bottom line (defaults to the hostname):
# export DOTFILES_LABEL="deathstar"
EOF
    echo "  created  $LOCAL_FILE"
else
    echo "  kept     $LOCAL_FILE (already present)"
fi

# Seed the untracked git identity file (never overwrite an existing one).
GIT_LOCAL="$LOCAL_DIR/gitconfig.local"
if [ ! -f "$GIT_LOCAL" ]; then
    cat > "$GIT_LOCAL" <<'EOF'
# Per-machine, untracked git identity + overrides — NOT part of the dotfiles
# repo. Fill these in once per machine:
#
# [user]
# 	name = Your Name
# 	email = you@example.com
EOF
    echo "  created  $GIT_LOCAL"
else
    echo "  kept     $GIT_LOCAL (already present)"
fi

echo "Done. Open a new shell, or run: reload"
