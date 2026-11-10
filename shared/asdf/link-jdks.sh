#!/usr/bin/env bash
# Symlink every asdf-installed JDK into ~/.jdks, where IntelliJ looks for JDKs automatically.
# install.sh runs this; run it again after `asdf install java <version>`.
set -euo pipefail

ASDF_DATA_DIR="${ASDF_DATA_DIR:-$HOME/asdf/data}"
mkdir -p "$HOME/.jdks"

for install in "$ASDF_DATA_DIR"/installs/java/*/; do
  [ -d "$install" ] || continue
  install="${install%/}"
  home="$install"
  [ -d "$install/Contents/Home" ] && home="$install/Contents/Home"   # macOS JDK bundle layout
  dest="$HOME/.jdks/asdf-$(basename "$install")"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "Skipping $dest: a real directory is already there"
    continue
  fi
  ln -sfn "$home" "$dest"
  echo "Linked $dest -> $home"
done
