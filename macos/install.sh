#!/usr/bin/env bash
# macOS setup. Run via ../install.sh, which defines `link` and DOTFILES.
set -euo pipefail

echo 'Installing software using brew'
brew bundle --file "$DOTFILES/macos/Brewfile"

# AWS CLI v2 from AWS's official pkg, not Homebrew: it bundles its own Python. Homebrew's awscli runs on
# python@3.15, whose pyexpat (3.15.2) needs a newer /usr/lib/libexpat than macOS 26.2 has, so `aws login` crashed.
if ! command -v aws >/dev/null || [ "$(command -v aws)" != /usr/local/bin/aws ]; then
  echo 'Installing AWS CLI v2 (official pkg, needs sudo)'
  pkg=$(mktemp -d)/AWSCLIV2.pkg
  curl -fsSL -o "$pkg" https://awscli.amazonaws.com/AWSCLIV2.pkg
  sudo installer -pkg "$pkg" -target /
  rm -f "$pkg"
fi

echo 'Setting up Hammerspoon'
link "$DOTFILES/macos/hammerspoon/init.lua" "$HOME/.hammerspoon/init.lua"
echo 'Remember: open Hammerspoon once and grant it Accessibility permission (System Settings > Privacy & Security > Accessibility)'

echo 'Linking the Zed keymap'
link "$DOTFILES/macos/zed/keymap.json" "$HOME/.config/zed/keymap.json"
