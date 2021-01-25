#Colors

# Normal Coloring
txtblk='\e[0;30m' # Black - Regular
txtred='\e[0;31m' # Red
txtgrn='\e[0;32m' # Green
txtylw='\e[0;33m' # Yellow
txtblu='\e[0;34m' # Blue
txtpur='\e[0;35m' # Purple
txtcyn='\e[0;36m' # Cyan
txtwht='\e[0;37m' # White

# Bold Coloring
bldblk='\e[1;30m' # Black - Bold
bldred='\e[1;31m' # Red
bldgrn='\e[1;32m' # Green
bldylw='\e[1;33m' # Yellow
bldblu='\e[1;34m' # Blue
bldpur='\e[1;35m' # Purple
bldcyn='\e[1;36m' # Cyan
bldwht='\e[1;37m' # White
 
# Underlined
unkblk='\e[4;30m' # Black - Underline
undred='\e[4;31m' # Red
undgrn='\e[4;32m' # Green
undylw='\e[4;33m' # Yellow
undblu='\e[4;34m' # Blue
undpur='\e[4;35m' # Purple
undcyn='\e[4;36m' # Cyan
undwht='\e[4;37m' # White
 
#Background Coloring
bakblk='\e[40m'   # Black - Background
bakred='\e[41m'   # Red
bakgrn='\e[42m'   # Green
bakylw='\e[43m'   # Yellow
bakblu='\e[44m'   # Blue
bakpur='\e[45m'   # Purple
bakcyn='\e[46m'   # Cyan
bakwht='\e[47m'   # White
txtrst='\e[0m'    # Text Reset

#Prompt

print_before_the_prompt () {
	printf "\n$bldgrn%s $bldpur%s\n$txtrst" "$PWD"
}

PROMPT_COMMAND=print_before_the_prompt
export PS1="-> "

#Aliases

#ssh
alias saturn="ssh bgnelson99@saturn"
alias saturnlab="ssh bgnelson99@saturnlab"
alias titan="ssh bgnelson99@titan"
alias titanlab="ssh bgnelson99@titanlab"

#color
alias ls="ls -l -G"
alias grep='grep --color'

#cd shortcuts
alias dl="cd ~/Downloads"
alias dk="cd ~/Desktop"
alias docs="cd ~/Documents"
alias ..="cd .."
alias home="cd ~"

#ls
alias lrth="ls -lrth"
alias lrtha="ls -lrtha"