export JAVA_HOME=$(/usr/libexec/java_home -v 17)

alias nrepl='clj -M:nREPL -m nrepl.cmdline'

alias python=python3
alias pip=pip3
alias all_javas="/usr/libexec/java_home -V"

# Git stuff
alias gs='git status'
alias gc='git commit -m'
alias ga='git add'
alias gaa='git add .'
alias gp='git push origin $(git rev-parse --abbrev-ref HEAD)'

# k8s stuff
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

# Docker stuff
alias lzd='lazydocker'

HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000000
SAVEHIST=100000000
setopt appendhistory
setopt INC_APPEND_HISTORY  
setopt SHARE_HISTORY
source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh

source <(fzf --zsh)

# nvm stuff
source $(brew --prefix nvm)/nvm.sh
export NVM_DIR="$HOME/.nvm"
[ -s "/usr/local/opt/nvm/nvm.sh" ] && \. "/usr/local/opt/nvm/nvm.sh"
[ -s "/usr/local/opt/nvm/etc/bash_completion" ] && \. "/usr/local/opt/nvm/etc/bash_completion"

# pnpm
export PNPM_HOME="/Users/kaleb.roncatti/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

autoload -Uz compinit && compinit

eval "$(oh-my-posh init zsh --config $(brew --prefix oh-my-posh)/themes/easy-term.omp.json)"
