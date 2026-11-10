#!/usr/bin/env bash
# macOS setup. Run via ../install.sh, which defines `link` and DOTFILES.
set -euo pipefail

echo 'Installing software using brew'
brew bundle --file "$DOTFILES/macos/Brewfile"

echo 'Setting up Hammerspoon'
link "$DOTFILES/macos/hammerspoon/init.lua" "$HOME/.hammerspoon/init.lua"
echo 'Remember: open Hammerspoon once and grant it Accessibility permission (System Settings > Privacy & Security > Accessibility)'
