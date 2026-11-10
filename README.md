# dotfiles

My setup for macOS and Fedora (KDE Plasma): packages, zsh config, and a few app configs.

## Install

```sh
git clone https://github.com/kroncatti/dotfiles.git ~/Documents/personal-projects/dotfiles
cd ~/Documents/personal-projects/dotfiles
./install.sh
```

`install.sh` detects the OS, runs `macos/install.sh` or `fedora/install.sh`, then symlinks the shared configs into `$HOME`.
Configs are symlinked, not copied, so edits in the repo apply right away.
Any file already at a target path is moved to `<file>.backup-<timestamp>` first.
Running `install.sh` again is safe.

## Layout

```
install.sh               entry point: detects OS, runs <os>/install.sh, links shared configs
shared/
  zsh/zshrc              ~/.zshrc on every machine: aliases, history, fzf, nvm, oh-my-posh
  vscode/launch/         VS Code launch configs (Go, TypeScript), copy into a project's .vscode/ as needed
macos/
  install.sh             brew bundle + Hammerspoon link
  Brewfile               Homebrew formulae and casks
  zshrc                  macOS paths: JAVA_HOME via java_home, Homebrew prefixes
  hammerspoon/init.lua   sets the Yodoit monitor's brightness on connect and wake (via m1ddc)
fedora/
  install.sh             dnf + Flatpak + VS Code/Brave repos, nvm, oh-my-posh, Nerd Font, Docker, zsh as login shell
  packages.txt           dnf packages
  flatpaks.txt           Flathub apps
  zshrc                  Fedora paths: JAVA_HOME from the `java` alternative, ~/.local/bin, ~/go/bin
```

## How the zsh config works

`~/.zshrc` is a symlink to `shared/zsh/zshrc`. It loads files in this order:

1. `<os>/zshrc`, which sets the OS-specific paths (`JAVA_HOME`, `NVM_SH`, `ZSH_AUTOSUGGESTIONS`, `OMP_CONFIG`, `PNPM_HOME`).
2. The shared aliases and tool setup.
3. `~/.zshrc.local`, if it exists.

**Put anything machine-specific or secret in `~/.zshrc.local`**: tokens, work aliases, extra `PATH` entries.
That file is never committed.

## Adding packages

| What | macOS | Fedora |
|---|---|---|
| CLI tool | `brew "name"` in `macos/Brewfile` | add to `fedora/packages.txt` |
| GUI app | `cask "name"` in `macos/Brewfile` | add the Flathub ID to `fedora/flatpaks.txt` |

## Fedora notes

The Fedora setup was tested in a Fedora 45 container. Things that differ from macOS:

- **Java**: Fedora 45 only ships OpenJDK 25 (no 17 or 21). For older JDKs, add the [Adoptium repo](https://adoptium.net/installation/linux/) or use SDKMAN.
  `JAVA_HOME` follows whichever version `sudo alternatives --config java` selects.
- **Not in the Fedora repos**: kubectx, kubens and lazydocker are installed with `go install` (into `~/go/bin`).
  VS Code and Brave come from their vendors' dnf repos. Spotify and IntelliJ come from Flathub.
- **Docker** is Fedora's `moby-engine`. Log out and back in after installing so the `docker` group membership applies.
- **Not set up on Fedora**: WhatsApp (no Linux app), iTerm2 (KDE ships Konsole), coursier, pnpm
  (run `npm i -g pnpm` after `nvm install --lts`).
- **Hammerspoon** is macOS only. On Linux the equivalent is `ddcutil` (in the Fedora repos), which isn't set up here.

## macOS notes

- After the first install, open Hammerspoon once and give it Accessibility permission.
  It then starts at login by itself.
