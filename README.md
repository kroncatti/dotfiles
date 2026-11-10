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
install.sh               entry point: detects OS, runs <os>/install.sh, links shared configs, runs asdf install
shared/
  zsh/zshrc              ~/.zshrc on every machine: aliases, history, fzf, asdf, oh-my-posh
  asdf/tool-versions     ~/.tool-versions on every machine: pinned Node.js and Java (LTS) versions
  asdf/link-jdks.sh      links asdf JDKs into ~/.jdks so IntelliJ detects them
  vscode/launch/         VS Code launch configs (Go, TypeScript), copy into a project's .vscode/ as needed
macos/
  install.sh             brew bundle + Hammerspoon link
  Brewfile               Homebrew formulae and casks
  zshrc                  macOS paths: Homebrew prefixes
  hammerspoon/init.lua   sets the Yodoit monitor's brightness on connect and wake (via m1ddc)
fedora/
  install.sh             dnf + Flatpak + VS Code/Brave repos, asdf, oh-my-posh, Nerd Font, Docker, zsh as login shell
  packages.txt           dnf packages
  flatpaks.txt           Flathub apps
  zshrc                  Fedora paths: ~/.local/bin, ~/go/bin
```

## How the zsh config works

`~/.zshrc` is a symlink to `shared/zsh/zshrc`. It loads files in this order:

1. `<os>/zshrc`, which sets the OS-specific paths (`ZSH_AUTOSUGGESTIONS`, `OMP_CONFIG`, `PNPM_HOME`).
2. The shared aliases and tool setup.
3. `~/.zshrc.local`, if it exists.

**Put anything machine-specific or secret in `~/.zshrc.local`**: tokens, work aliases, extra `PATH` entries.
That file is never committed.

## Node.js and Java versions (asdf)

Both OSes use [asdf](https://asdf-vm.com) with its data in `~/asdf/data`.
`~/.tool-versions` is a symlink to `shared/asdf/tool-versions`, so every machine gets the same versions.
It pins the current LTS releases: Node.js 26 and Java 25 (Eclipse Temurin; asdf-java still lists it under the `adoptopenjdk-` name).
`JAVA_HOME` is set by the asdf Java plugin and follows whichever Java version is active.

- Change the global Node.js version: `asdf install nodejs <version> && asdf set --home nodejs <version>`.
  This edits the file in the repo through the symlink, so commit it afterwards.
- Change the global Java version: `asdf list all java | grep adoptopenjdk-25` to see versions, then `asdf install java <version> && asdf set --home java <version>`.
  List installed JDKs with `all_javas`.
- Add another tool: add a `<plugin> <version>` line to `shared/asdf/tool-versions` and run `./install.sh` again.
  It adds any missing plugins and installs the listed versions.
- Per-project versions: a `.tool-versions` file in a project directory overrides the global one.
- **IntelliJ**: `install.sh` symlinks every asdf JDK into `~/.jdks/asdf-<version>`, a folder IntelliJ scans for JDKs.
  After installing another JDK with asdf, run `shared/asdf/link-jdks.sh` so IntelliJ picks it up.

## Adding packages

| What | macOS | Fedora |
|---|---|---|
| CLI tool | `brew "name"` in `macos/Brewfile` | add to `fedora/packages.txt` |
| GUI app | `cask "name"` in `macos/Brewfile` | add the Flathub ID to `fedora/flatpaks.txt` |

## Fedora notes

The Fedora setup was tested in a Fedora 45 container. Things that differ from macOS:

- **Not in the Fedora repos**: asdf, kubectx, kubens and lazydocker are installed with `go install` (into `~/go/bin`).
  VS Code and Brave come from their vendors' dnf repos. Spotify and IntelliJ come from Flathub.
- **Docker** is Fedora's `moby-engine`. Log out and back in after installing so the `docker` group membership applies.
- **Not set up on Fedora**: WhatsApp (no Linux app), iTerm2 (KDE ships Konsole), coursier, pnpm
  (add `pnpm <version>` to `shared/asdf/tool-versions`).
- **Hammerspoon** is macOS only. On Linux the equivalent is `ddcutil` (in the Fedora repos), which isn't set up here.

## macOS notes

- After the first install, open Hammerspoon once and give it Accessibility permission.
  It then starts at login by itself.
