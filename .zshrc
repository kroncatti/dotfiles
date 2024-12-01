export JAVA_HOME=/Library/Java/JavaVirtualMachines/amazon-corretto-11.jdk/Contents/Home

alias nrepl='clj -M:nREPL -m nrepl.cmdline'

alias python=python3
alias pip=pip3
alias all_javas="/usr/libexec/java_home -V"

HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000000
SAVEHIST=100000000
setopt appendhistory
setopt INC_APPEND_HISTORY  
setopt SHARE_HISTORY
source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh

source <(fzf --zsh)

eval "$(oh-my-posh init zsh --config $(brew --prefix oh-my-posh)/themes/easy-term.omp.json)"
