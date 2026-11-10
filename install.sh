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
link "$DOTFILES/shared/asdf/tool-versions" "$HOME/.tool-versions"

echo '==> Installing tool versions with asdf'
export ASDF_DATA_DIR="$HOME/asdf/data"
export PATH="$ASDF_DATA_DIR/shims:$HOME/go/bin:$PATH"
mkdir -p "$ASDF_DATA_DIR/completions"
asdf completion zsh > "$ASDF_DATA_DIR/completions/_asdf"
cut -d" " -f1 "$HOME/.tool-versions" | while read -r plugin; do asdf plugin add "$plugin" 2>/dev/null || true; done
(cd "$HOME" && asdf install)

echo '==> Linking asdf JDKs into ~/.jdks for IntelliJ'
"$DOTFILES/shared/asdf/link-jdks.sh"

echo
echo 'Done. Put machine-specific or secret settings (tokens, work aliases) in ~/.zshrc.local; it is sourced but never committed.'
