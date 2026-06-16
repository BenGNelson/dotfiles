# Shared aliases — sourced by both bash and zsh.

# ls — detect GNU (Linux/WSL) vs BSD (macOS)
if ls --color=auto /dev/null > /dev/null 2>&1; then
    alias ls='ls -lh --color=auto'
    alias lrth='ls -lrth --color=auto'
    alias lrtha='ls -lrtha --color=auto'
    alias ll='ls -lh --color=auto'
    alias la='ls -lha --color=auto'
else
    alias ls='ls -lhG'
    alias lrth='ls -lrthG'
    alias lrtha='ls -lrthaG'
    alias ll='ls -lhG'
    alias la='ls -lhaG'
fi

alias grep='grep --color=auto'

# cd shortcuts
alias dl="cd ~/Downloads"
alias dk="cd ~/Desktop"
alias docs="cd ~/Documents"
alias ..="cd .."
alias ...="cd ../.."
alias home="cd ~"

# git
alias gs="git status"
alias ga="git add"
alias gc="git commit"
alias gd="git diff"
alias gl="git log --oneline --graph --decorate"
alias gp="git push"
alias gco="git checkout"
alias gb="git branch"

# safer file ops — prompt before clobbering (interactive use only)
alias rm="rm -i"
alias cp="cp -i"
alias mv="mv -i"

# make a directory and cd into it
mkcd() { mkdir -p "$1" && cd "$1"; }

# extract almost any archive: extract foo.tar.gz
extract() {
    if [ -z "$1" ] || [ ! -f "$1" ]; then
        echo "usage: extract <archive>"; return 1
    fi
    case "$1" in
        *.tar.bz2)  tar xjf "$1" ;;
        *.tar.gz)   tar xzf "$1" ;;
        *.tar.xz)   tar xJf "$1" ;;
        *.tar)      tar xf  "$1" ;;
        *.tbz2)     tar xjf "$1" ;;
        *.tgz)      tar xzf "$1" ;;
        *.bz2)      bunzip2 "$1" ;;
        *.gz)       gunzip  "$1" ;;
        *.zip)      unzip   "$1" ;;
        *.rar)      unrar x "$1" ;;
        *.7z)       7z x    "$1" ;;
        *.Z)        uncompress "$1" ;;
        *)          echo "extract: don't know how to extract '$1'"; return 1 ;;
    esac
}

# re-source shell config
alias reload="exec \$SHELL -l"

# pull the latest dotfiles and re-run the installer
alias dot-update="git -C ~/dotfiles pull --ff-only && ~/dotfiles/install.sh"
