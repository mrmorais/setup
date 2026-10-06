# setup

Reproducible configuration for my development machines.

Each top-level directory is one self-contained piece of the setup, with its own
README describing what it is and how to install it from scratch.

| Directory | What it covers |
|---|---|
| [`emacs/`](emacs/) | GNU Emacs 31 config — eglot/LSP for C/C++, Java, Kotlin, JS/TS, plus CMake and Gradle build commands |

## Conventions

- Configuration files are kept in this repo and **symlinked** into place by each
  component's `install.sh`. Editing the live config edits the repo copy, so a
  change is never lost and `git status` always shows drift.
- Every `install.sh` is idempotent: re-running it on an already-configured
  machine is a no-op plus any missing pieces.
- Primary target is macOS on Apple Silicon with Homebrew; Ubuntu (x86_64 /
  arm64) is also supported. Platform-specific steps are called out in the
  component README.
