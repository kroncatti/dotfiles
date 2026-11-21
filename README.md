# dotfiles

My setup for macOS and Fedora (KDE Plasma): packages, zsh config, and a few app configs.

## Install

```sh
git clone https://github.com/kroncatti/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

`install.sh` detects the OS, runs `macos/install.sh` or `fedora/install.sh`, then symlinks the shared configs into `$HOME`.
Configs are symlinked, not copied, so edits in the repo apply right away.
Any file already at a target path is moved to `<file>.backup-<timestamp>` first.
Running `install.sh` again is safe.

## Layout

```
install.sh               entry point: detects OS, runs <os>/install.sh, links shared configs, runs asdf install, installs Metals
shared/
  zsh/zshrc              ~/.zshrc on every machine: aliases, history, fzf, asdf, oh-my-posh
  asdf/tool-versions     ~/.tool-versions on every machine: pinned Node.js and Java (LTS) versions
  asdf/link-jdks.sh      links asdf JDKs into ~/.jdks so IntelliJ detects them
  zed/settings.json      ~/.config/zed/settings.json on every machine: theme, icons, extensions, Metals (Scala)
  zed/tasks.json         ~/.config/zed/tasks.json on every machine: Clojure REPL and paredit tasks
  zed/clojure.bb         ~/.config/zed/clojure.bb: babashka script behind those tasks (nREPL client, paredit)
  vscode/launch/         VS Code launch configs (Go, TypeScript), copy into a project's .vscode/ as needed
macos/
  install.sh             brew bundle + Hammerspoon link
  Brewfile               Homebrew formulae and casks
  zshrc                  macOS paths: Homebrew prefixes
  hammerspoon/init.lua   sets the Yodoit monitor's brightness on connect and wake (via m1ddc)
  zed/keymap.json        ~/.config/zed/keymap.json on macOS (Cmd-based bindings)
fedora/
  install.sh             dnf + Flatpak + VS Code/Brave repos, asdf, oh-my-posh, Nerd Font, Zed, coursier, babashka, Docker, zsh as login shell
  packages.txt           dnf packages
  flatpaks.txt           Flathub apps
  zshrc                  Fedora paths: ~/.local/bin, ~/go/bin
  zed/keymap.json        ~/.config/zed/keymap.json on Fedora (same bindings, Ctrl instead of Cmd)
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

## Zed

Zed is installed with Homebrew on macOS and with Zed's official script on Fedora (into `~/.local/bin/zed`).
Its config is symlinked like everything else:

- `shared/zed/settings.json` → `~/.config/zed/settings.json` (the same path on both OSes).
- `<os>/zed/keymap.json` → `~/.config/zed/keymap.json`. Zed keymaps can't vary by OS, and Linux has no Cmd key, so each OS has its own file.

**Extensions** are listed in `auto_install_extensions` in `settings.json`. Zed installs any missing ones the next time it starts.
To add one, install it from `zed: extensions` and add its ID to that list.

**Scala**: the Scala extension runs the `metals` launcher from coursier (`~/.local/share/coursier/bin`, put on `PATH` by `shared/zsh/zshrc`).
`install.sh` installs it with `cs install metals`; update it later with `cs update metals`.
The `-J--add-exports` flags in `settings.json` are needed on JDK 17+, or Metals fails to index Java sources and can crash.

**Keybindings** on top of the JetBrains base keymap:

| Keys | Action |
|---|---|
| Shift Shift | file finder (like IntelliJ's Search Everywhere) |
| Cmd Cmd (macOS) / Ctrl Ctrl (Fedora) | toggle inlay hints (inferred types, implicits) |

### Clojure

The Clojure extension gives syntax highlighting and clojure-lsp (it downloads clojure-lsp itself if it isn't on `PATH`).
Zed has no nREPL client and no paredit, so `shared/zed/clojure.bb` (run with [babashka](https://babashka.org)) fills in, called from tasks in `shared/zed/tasks.json`.
The keys below follow Cursive and only apply in `.clj`, `.cljs`, `.cljc`, `.edn` and `.bb` files.

1. Start a REPL: `task: spawn` → **clojure: start nREPL**. It looks at the project root: `deps.edn` runs `clojure` with nREPL and cider-nrepl added (set `CLJ_ALIASES=:dev:test` to add aliases), `project.clj` runs `lein repl`, `bb.edn` runs `bb nrepl-server`.
   That terminal is also an interactive REPL on the same server. A REPL you started yourself works too, as long as it writes `.nrepl-port`.
2. Evaluate with the keys below. Output appears in a terminal tab named after the task. Forms run in the file's namespace, and the file is loaded first if the REPL hasn't seen that namespace yet.

| macOS | Fedora | Action |
|---|---|---|
| Ctrl Shift P | Alt Shift P | eval the selection, or the top-level form at the cursor |
| Ctrl Shift E | Alt Shift E | eval the form that ends right before the cursor |
| Ctrl Shift L | Alt Shift L | load the file in the REPL |
| Cmd Shift K | Ctrl Shift K | slurp forward |
| Cmd Shift J | Ctrl Shift J | barf forward |
| Ctrl Cmd J | Ctrl Alt J | slurp backward |
| Ctrl Cmd K | Ctrl Alt K | barf backward |
| Ctrl Cmd R | Alt Shift U | raise (replace the enclosing form with the one at the cursor) |
| Ctrl Cmd U | Ctrl Alt U | splice (remove the enclosing brackets) |

Cursive puts the REPL keys on Cmd Shift, but in Zed those are the command palette (Cmd Shift P), the project panel and select-all-matches, so they use Ctrl Shift here.
In Clojure files these keys override Zed's: Cmd Shift K (delete line; git push in other files still works), Cmd Shift J (search filters),
Ctrl Shift P/E (select up / select to end of line). On Fedora: Ctrl Shift K/J (delete line, join lines), Ctrl Alt J/K (workspace sidebar, agent thinking mode).

Limits of doing this with tasks:

- Paredit saves the buffer, rewrites the file with rewrite-clj and lets Zed reload it, so each edit is a separate undo step and takes a moment longer than a built-in action.
- Each evaluation opens a new nREPL session, so `*1`, `*e` and `set!` vars don't carry over between evaluations. They do in the interactive REPL terminal.
- Results show in the terminal, not inline in the editor.
- Debug the nREPL traffic with `ZED_CLJ_DEBUG=1 bb ~/.config/zed/clojure.bb eval <file> <row> <col>`.

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
- **coursier** isn't in the Fedora repos; `install.sh` downloads the `cs` binary into `~/.local/bin`.
- **Not set up on Fedora**: WhatsApp (no Linux app), iTerm2 (KDE ships Konsole), pnpm
  (add `pnpm <version>` to `shared/asdf/tool-versions`).
- **Hammerspoon** is macOS only. On Linux the equivalent is `ddcutil` (in the Fedora repos), which isn't set up here.

## macOS notes

- After the first install, open Hammerspoon once and give it Accessibility permission.
  It then starts at login by itself.
- Homebrew refuses formulae from third-party taps it doesn't trust yet. On a fresh Mac, `brew bundle` stops on
  `clojure/tools`, `borkdude/brew` (babashka) and `jandedobbeleer/oh-my-posh` until you run
  `brew trust --tap clojure/tools borkdude/brew jandedobbeleer/oh-my-posh`.
- Apps already installed without Homebrew make `brew bundle` (and so `install.sh`) fail.
  Hand them to Homebrew with `brew install --cask --adopt <cask>`, or remove them first.
