# LS_COLORS — rich file type coloring for ls
if command -v dircolors > /dev/null 2>&1; then
    eval "$(dircolors -b)"
fi

#Colors
source ~/dotfiles/bash/prompt.bash

#Aliases
source ~/dotfiles/shell/aliases.sh