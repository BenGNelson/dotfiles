# Package-manager-agnostic tool installer, shared by bootstrap.sh and test.sh.
# Source this file, then call:  dotfiles_install_tools git vim tmux
#
# Supports the four mainstream Linux package-manager families. Package names for
# git/vim/tmux/zsh happen to be identical across all of them, so a single call
# works everywhere.

dotfiles_install_tools() {
    [ "$#" -gt 0 ] || return 0
    local sudo=""
    [ "$(id -u)" -ne 0 ] && command -v sudo > /dev/null 2>&1 && sudo="sudo"

    if command -v apt-get > /dev/null 2>&1; then
        $sudo apt-get update -qq
        DEBIAN_FRONTEND=noninteractive $sudo apt-get install -y "$@"
    elif command -v dnf > /dev/null 2>&1; then
        $sudo dnf install -y "$@"
    elif command -v pacman > /dev/null 2>&1; then
        $sudo pacman -Sy --noconfirm "$@"
    elif command -v zypper > /dev/null 2>&1; then
        $sudo zypper --non-interactive install "$@"
    else
        echo "No supported package manager found (need apt-get, dnf, pacman, or zypper)." >&2
        echo "Install these yourself and re-run: $*" >&2
        return 1
    fi
}
