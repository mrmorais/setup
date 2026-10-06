# setup

Reproducible configuration for my development machines.

Each top-level directory is one self-contained piece of the setup, with its own
README describing what it is and how to install it from scratch.

| Directory | What it covers |
|---|---|
| [`emacs/`](emacs/) | GNU Emacs 31 config — eglot/LSP for C/C++, Java, Kotlin, JS/TS, plus CMake and Gradle build commands |
| [`claude/`](claude/) | Claude Code — global instructions, settings, MCP servers, plugins, and the skill library |

## Conventions

- Configuration files are kept in this repo and **symlinked** into place by each
  component's `install.sh`. Editing the live config edits the repo copy, so a
  change is never lost and `git status` always shows drift.
- Every `install.sh` is idempotent: re-running it on an already-configured
  machine is a no-op plus any missing pieces.
- Target platform is macOS on Apple Silicon with Homebrew. Steps that are
  macOS-specific are called out in the component README.
- **This repo is public.** Nothing work-related is published here — no internal
  skills, plugins, marketplaces, endpoints or identifiers — and no credentials.
  Config that would otherwise carry a secret is committed as a template with
  `${PLACEHOLDER}` values. Files that a tool rewrites on its own are copied
  rather than symlinked, so private state cannot leak back in through an edit.

