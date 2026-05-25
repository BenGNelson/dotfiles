# ls — detect GNU (Linux/WSL) vs BSD (macOS)
if ls --color=auto /dev/null > /dev/null 2>&1; then
    alias ls='ls -lh --color=auto'
    alias lrth='ls -lrth --color=auto'
    alias lrtha='ls -lrtha --color=auto'
else
    alias ls='ls -lhG'
    alias lrth='ls -lrthG'
    alias lrtha='ls -lrthaG'
fi

alias grep='grep --color=auto'

# cd shortcuts
alias dl="cd ~/Downloads"
alias dk="cd ~/Desktop"
alias docs="cd ~/Documents"
alias ..="cd .."
alias home="cd ~"

# git
alias gs="git status"
