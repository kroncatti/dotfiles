#!/usr/bin/env bash
# Fedora (KDE Plasma) setup. Run via ../install.sh, which defines `link` and DOTFILES.
set -euo pipefail
HERE="$DOTFILES/fedora"
packages() { grep -vE '^\s*(#|$)' "$1"; }

echo 'Adding VS Code and Brave repos'
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo tee /etc/yum.repos.d/vscode.repo >/dev/null <<'REPO'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
REPO
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager addrepo --overwrite --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo

echo 'Installing dnf packages'
sudo dnf install -y $(packages "$HERE/packages.txt") code brave-browser

echo 'Installing Flatpak apps'
flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install -y --user flathub $(packages "$HERE/flatpaks.txt")

echo 'Installing Go-based CLIs (kubectx, kubens, lazydocker)'
go install github.com/ahmetb/kubectx/cmd/kubectx@latest
go install github.com/ahmetb/kubectx/cmd/kubens@latest
go install github.com/jesseduffield/lazydocker@latest

echo 'Installing nvm'
[ -d "$HOME/.nvm" ] || PROFILE=/dev/null bash -c 'curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash'

echo 'Installing oh-my-posh and the easy-term theme'
mkdir -p "$HOME/.local/bin" "$HOME/.config/oh-my-posh"
curl -fsSL https://ohmyposh.dev/install.sh | bash -s -- -d "$HOME/.local/bin"
curl -fsSL -o "$HOME/.config/oh-my-posh/easy-term.omp.json" \
  https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/easy-term.omp.json

echo 'Installing FiraCode Nerd Font'
FONT_DIR="$HOME/.local/share/fonts/FiraCodeNerdFont"
if [ ! -d "$FONT_DIR" ]; then
  mkdir -p "$FONT_DIR"
  curl -fsSL -o /tmp/FiraCode.zip https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip
  unzip -oq /tmp/FiraCode.zip -d "$FONT_DIR" && rm /tmp/FiraCode.zip
  fc-cache -f
fi

echo 'Enabling Docker'
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"

if [ "$(basename "${SHELL:-}")" != zsh ]; then
  echo 'Making zsh the login shell'
  sudo usermod -s "$(command -v zsh)" "$USER"
fi

echo 'Log out and back in for the docker group and the zsh login shell to take effect.'
