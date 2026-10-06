# Emacs

GNU Emacs 31 on macOS, configured as a working editor for C/C++, Java, Kotlin
and JavaScript/TypeScript. Everything goes through the built-in **eglot** LSP
client and **tree-sitter** major modes; the only third-party packages are the
theme, completion popup, Kotlin mode, Groovy mode and Magit.

## What's here

```
emacs/
├── README.md        # this file
├── install.sh       # idempotent bootstrap
└── emacs.d/
    ├── init.el      # the whole configuration
    └── custom.el    # Custom's auto-generated settings (package-selected-packages)
```

`install.sh` symlinks both files into `~/.emacs.d/`, so edits made inside Emacs
land in this repo.

## Quick start

```sh
git clone https://github.com/mrmorais/setup.git ~/Projetos/setup
~/Projetos/setup/emacs/install.sh
```

Then open Emacs. ELPA packages install themselves on first launch. Finally run
`M-x mm/treesit-install-missing` to compile the tree-sitter grammars (needs a C
compiler and `git`, both present with the Xcode command line tools).

---

## Components

### Emacs itself

Installed from the [emacsformacosx.com](https://emacsformacosx.com/) build via
Homebrew Cask:

```sh
brew install --cask emacs-app
```

This gives `/Applications/Emacs.app` plus `emacs` / `emacsclient` symlinks in
`/opt/homebrew/bin`. On Ubuntu use the snap (`sudo snap install emacs --classic`),
which currently tracks 31.x. Pinned to the 31.x line — the config uses `treesit`,
`fido-vertical-mode` and the bundled eglot, all of which need Emacs 29+, and
`java-ts-mode` which needs 30+.

### ELPA packages

MELPA is added to `package-archives`, and `mm/require` installs anything
missing on startup, so no manual `package-install` is ever needed.

| Package | Why |
|---|---|
| `gruber-darker-theme` | theme |
| `exec-path-from-shell` | a GUI Emacs on macOS is launched by the window server and never sees `.zshrc`'s PATH — without this it cannot find `clangd`, `node`, etc. |
| `company` | completion popup, enabled per language hook |
| `kotlin-ts-mode` | Kotlin major mode (not bundled) |
| `groovy-mode` | Gradle `.gradle` build files |
| `magit` | Git |

`flycheck` is present in `custom.el`'s `package-selected-packages` from an
earlier iteration but is no longer required by `init.el`; eglot supplies
diagnostics through Flymake.

### Tree-sitter grammars

Emacs ships the `*-ts-mode` major modes but **not** the grammars. The sources
are declared in `init.el`; `M-x mm/treesit-install-missing` clones and compiles
every one that is absent into `~/.emacs.d/tree-sitter/`:

`java`, `kotlin`, `javascript`, `typescript`, `tsx`, `json`, `jsdoc`

Grammars are machine-local build artifacts and are deliberately *not* committed.

---

## Language servers

These live outside `~/.emacs.d` and must be installed separately. `install.sh`
handles all of them.

### C / C++ — clangd

Ships with the Xcode command line tools at `/usr/bin/clangd`:

```sh
xcode-select --install
```

On Ubuntu: `sudo apt install clangd cmake`.

eglot already knows to launch `clangd` for `c-mode` / `c++-mode`. It needs a
`compile_commands.json` at the project root to resolve includes — CMake emits
one with `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON` (or `set(CMAKE_EXPORT_COMPILE_COMMANDS ON)`).

### Java — Eclipse JDT Language Server

Installed to `~/.local/share/jdtls`, with a symlink at `~/.local/bin/jdtls`.
Downloaded from the Eclipse snapshot build:

```
https://download.eclipse.org/jdtls/snapshots/jdt-language-server-latest.tar.gz
```

Two JDK facts drive the config:

- **jdtls refuses to start on anything below JDK 21**, so it is launched with
  `--java-executable` pointing at the newest installed JDK 25 (falling back to 21).
- The projects themselves still target Java 11, so jdtls is handed the full list
  of installed JDKs via `eglot-workspace-configuration`
  (`:java (:configuration (:runtimes ...))`) and compiles each module against
  its real target.

JDKs come from [SDKMAN!](https://sdkman.io/) under
`~/.sdkman/candidates/java/`. The config probes for majors **11, 17, 21 and 25**;
whatever is present is registered, whatever is missing is skipped.

### Kotlin — JetBrains kotlin-lsp

Installed to `~/.local/share/kotlin-lsp`. Current build: **2026.3 EAP
(`ILS-263.4702.0`)**. Releases:

```
https://github.com/Kotlin/kotlin-lsp/releases
```

Launched as `bin/intellij-server --stdio` (the older `kotlin-lsp.sh` entry point
is deprecated). It bundles its own JBR, so it does not use the SDKMAN JDKs.

It is passed `--system-path=~/.cache/kotlin-lsp`; without that flag the IntelliJ
indexes land in a temp dir and are rebuilt from scratch on every restart.

### JavaScript / TypeScript

Which server runs depends on the TypeScript version the *project* pins:

- **TypeScript ≥ 7** dropped `tsserver.js` and speaks LSP from the `tsc` binary
  directly, so the project's own `node_modules/.bin/tsc --lsp --stdio` is used.
- **Older projects** fall back to `~/.local/bin/typescript-language-server --stdio`.

`mm/typescript-server` probes `tsc --version` from the nearest `node_modules/.bin`
and picks. The fallback pair is installed globally into `~/.local`:

```sh
npm install --prefix ~/.local -g typescript typescript-language-server
```

Node comes from [nvm](https://github.com/nvm-sh/nvm) (currently v22).

---

## Build commands

### CMake — `C-c c` / `C-c t`

Both helpers find the project from the nearest `CMakeLists.txt`, drive an
out-of-source `build/` directory, and run `cmake -S . -B build` first when the
cache is absent — so a fresh clone needs no manual configure step.

- `C-c c` — `mm/cmake`, prompts for a target (default `all`)
- `C-c t` — `mm/ctest`, builds then runs `ctest --output-on-failure`

Plain `M-x compile` is also rebound in C/C++ buffers to `cmake --build build`
instead of the `make -k` default.

### Gradle — `C-c g`

`mm/gradlew` runs `./gradlew <task>` from the nearest directory containing
`gradlew`. Gradle 7.x does not run on JDK 21+, so the wrapper is invoked with
`JAVA_HOME` forced to the JDK the project actually targets (11, falling back
to 17) rather than whatever SDKMAN currently points at.

---

## Keybindings

| Key | Command |
|---|---|
| `C-c c` | `mm/cmake` — build a CMake target |
| `C-c t` | `mm/ctest` — build and run the test suite |
| `C-c g` | `mm/gradlew` — run a Gradle task |
| `C-c n` | `next-error` |
| `C-c p` | `previous-error` |
| `C-c m s` | `magit-status` |
| `C-c m l` | `magit-log` |

## Editor defaults

- `gruber-darker` theme, no tool bar / menu bar / scroll bar
- relative line numbers, column number in the modeline, `show-paren-mode`
- `fido-vertical-mode` for minibuffer completion (built in, no Vertico/Ivy)
- 4-space indentation, spaces not tabs
- no backup files, no splash screen, confirm before quitting
- `compilation-scroll-output` on

---

## Reproducing on a new machine

1. Install the Xcode command line tools: `xcode-select --install`
2. Install [Homebrew](https://brew.sh/)
3. Install [SDKMAN!](https://sdkman.io/) and the JDKs you need
   (`sdk install java 25.0.4-amzn`, `21.0.10-amzn`, `11.0.28-tem`, …)
4. Install [nvm](https://github.com/nvm-sh/nvm) and a Node LTS
5. Clone this repo and run `emacs/install.sh`
6. Launch Emacs, let ELPA packages install, then `M-x mm/treesit-install-missing`

On Ubuntu, replace steps 1–2 with `sudo apt install clangd cmake git curl zip unzip build-essential`
and `sudo snap install emacs --classic`; the rest is identical. `install.sh`
picks the matching kotlin-lsp archive for the OS and CPU.

Steps 3 and 4 are only needed for the Java/Kotlin and JS/TS setups
respectively — `install.sh` warns and skips rather than failing if they are
absent.

## Keeping it in sync

`install.sh` symlinks `~/.emacs.d/init.el` and `~/.emacs.d/custom.el` at this
repo, so editing the config from inside Emacs edits the tracked files directly.
Commit from here as usual.

Anything else under `~/.emacs.d/` — `elpa/`, `eln-cache/`, `tree-sitter/`,
`auto-save-list/`, `ido.last`, `projects.eld` — is a regenerable artifact or
machine-local state and is not tracked.
