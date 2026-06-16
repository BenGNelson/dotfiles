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

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BEGIN="# >>> dotfiles >>>"
END="# <<< dotfiles <<<"

# ensure_block <target_file> <source_path>
# Idempotently install/update the managed block in <target_file>.
ensure_block() {
    local target="$1" src="$2"
    local block
    block=$(printf '%s\n# managed by ~/dotfiles/install.sh — edit the repo, not this block\nsource %s\n%s' \
        "$BEGIN" "$src" "$END")

    if [ -f "$target" ] && grep -qF "$BEGIN" "$target"; then
        # Block exists — replace everything between the markers (inclusive).
        local tmp
        tmp=$(mktemp)
        awk -v b="$BEGIN" -v e="$END" -v repl="$block" '
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

echo "Installing dotfiles from $REPO ..."

ensure_block "$HOME/.bashrc"       "$REPO/bash/bashrc"
ensure_block "$HOME/.bash_profile" "$REPO/bash/bash_profile"
ensure_block "$HOME/.zshrc"        "$REPO/zsh/zshrc"
ensure_block "$HOME/.vimrc"        "$REPO/vim/vimrc"
ensure_block "$HOME/.tmux.conf"    "$REPO/tmux/tmux.conf"

# Seed the untracked per-machine override file (never overwrite an existing one).
LOCAL_DIR="$HOME/.config/dotfiles"
LOCAL_FILE="$LOCAL_DIR/local.sh"
if [ ! -f "$LOCAL_FILE" ]; then
    mkdir -p "$LOCAL_DIR"
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

echo "Done. Open a new shell, or run: reload"
