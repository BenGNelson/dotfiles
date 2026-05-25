# Colors (for use in printf/PROMPT_COMMAND context)
txtblk='\e[0;30m'
txtred='\e[0;31m'
txtgrn='\e[0;32m'
txtylw='\e[0;33m'
txtblu='\e[0;34m'
txtpur='\e[0;35m'
txtcyn='\e[0;36m'
txtwht='\e[0;37m'
bldblk='\e[1;30m'
bldred='\e[1;31m'
bldgrn='\e[1;32m'
bldylw='\e[1;33m'
bldblu='\e[1;34m'
bldpur='\e[1;35m'
bldcyn='\e[1;36m'
bldwht='\e[1;37m'
txtrst='\e[0m'

# Returns: "branch[*] [↑N] [↓N]" when inside a git repo, empty otherwise
_git_info() {
    local branch dirty info upstream behind ahead
    branch=$(git symbolic-ref --short HEAD 2>/dev/null) || return
    if ! git diff --quiet --ignore-submodules 2>/dev/null || \
       ! git diff --cached --quiet --ignore-submodules 2>/dev/null; then
        dirty="*"
    fi
    upstream=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)
    if [[ -n "$upstream" ]]; then
        read -r behind ahead < <(git rev-list --count --left-right "$upstream"...HEAD 2>/dev/null)
        [[ "${ahead:-0}" -gt 0 ]] && info+=" ↑$ahead"
        [[ "${behind:-0}" -gt 0 ]] && info+=" ↓$behind"
    fi
    printf '%s' "${branch}${dirty}${info}"
}

print_before_the_prompt() {
    local git_status git_part=""
    git_status=$(_git_info)
    if [[ -n "$git_status" ]]; then
        if [[ "$git_status" == *"*"* ]] || [[ "$git_status" == *"↓"* ]]; then
            git_part=$(printf " \e[1;31m(%s)\e[0m" "$git_status")
        else
            git_part=$(printf " \e[1;33m(%s)\e[0m" "$git_status")
        fi
    fi
    printf "\n\e[1;36m%s\e[0m%s\n" "$PWD" "$git_part"
}

PROMPT_COMMAND=print_before_the_prompt
# \h = short hostname (dynamic — set with: sudo hostnamectl set-hostname <name>)
PS1='\[\033[1;32m\]\h\[\033[0m\]-> '
