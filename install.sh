#!/usr/bin/env bash
# Entry point: installs packages for this OS, then links the configs into $HOME.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES

case "$(uname -s)" in
  Darwin) OS=macos ;;
  Linux)
    if grep -qi fedora /etc/os-release 2>/dev/null; then OS=fedora
    else echo "Unsupported Linux distro (only Fedora has a setup here)" >&2; exit 1; fi ;;
  *) echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac

# Symlink $1 -> $2, backing up anything already at $2
link() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ] && [ "$(readlink "$dest")" != "$src" ]; then
    local backup="$dest.backup-$(date +%Y%m%d%H%M%S)"
    mv "$dest" "$backup"
    echo "Backed up existing $dest to $backup"
  fi
  ln -sfn "$src" "$dest"
}
export -f link

echo "==> Running $OS setup"
"$DOTFILES/$OS/install.sh"

echo '==> Linking shared configs'
link "$DOTFILES/shared/zsh/zshrc" "$HOME/.zshrc"

echo
echo 'Done. Put machine-specific or secret settings (tokens, work aliases) in ~/.zshrc.local; it is sourced but never committed.'
