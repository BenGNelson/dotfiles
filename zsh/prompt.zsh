autoload -U colors && colors
setopt prompt_subst

# Returns: "branch[*] [↑N] [↓N]" when inside a git repo, empty otherwise.
# Mirrors _git_info() from bash/prompt.bash so both shells look identical.
_dot_git_info() {
    local branch dirty info upstream behind ahead
    branch=$(git symbolic-ref --short HEAD 2>/dev/null) || return
    if ! git diff --quiet --ignore-submodules 2>/dev/null || \
       ! git diff --cached --quiet --ignore-submodules 2>/dev/null; then
        dirty="*"
    fi
    upstream=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)
    if [[ -n "$upstream" ]]; then
        read -r behind ahead <<< "$(git rev-list --count --left-right "${upstream}"...HEAD 2>/dev/null)"
        [[ "${ahead:-0}" -gt 0 ]] && info+=" ↑$ahead"
        [[ "${behind:-0}" -gt 0 ]] && info+=" ↓$behind"
    fi
    print -r -- "${branch}${dirty}${info}"
}

# Colored git segment: red when dirty or behind, yellow otherwise.
_dot_git_segment() {
    local s=$(_dot_git_info)
    [[ -z "$s" ]] && return
    if [[ "$s" == *"*"* || "$s" == *"↓"* ]]; then
        print -r -- " %F{red}(${s})%f"
    else
        print -r -- " %F{yellow}(${s})%f"
    fi
}

# Machine label: live short hostname by default, DOTFILES_LABEL override if set
# in ~/.config/dotfiles/local.sh (sourced before this file).
_dot_label="${DOTFILES_LABEL:-${HOST%%.*}}"

# Top line: cyan working dir + git status.  Bottom line: green label + arrow.
PROMPT='%F{cyan}%~%f$(_dot_git_segment)'$'\n'"%F{green}${_dot_label}%f -> "
