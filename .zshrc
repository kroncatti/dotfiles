export JAVA_HOME=/Library/Java/JavaVirtualMachines/amazon-corretto-11.jdk/Contents/Home

alias nrepl='clj -M:nREPL -m nrepl.cmdline'

alias python=python3
alias pip=pip3
alias all_javas="/usr/libexec/java_home -V"

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

# pnpm
export PNPM_HOME="/Users/kaleb.roncatti/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

autoload -Uz compinit && compinit

eval "$(oh-my-posh init zsh --config $(brew --prefix oh-my-posh)/themes/easy-term.omp.json)"
