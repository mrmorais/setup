#!/usr/bin/env bash
#
# Bootstrap the shell helpers.
#
# Symlinks everything in shell/bin into ~/.local/bin, so editing a helper here
# edits the one on PATH.
#
# Idempotent. Nothing is overwritten without --force.
#
# Usage:
#   shell/install.sh           install what is missing
#   shell/install.sh --force   also replace existing files and links

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_BIN="$HOME/.local/bin"
FORCE=0
[[ "${1:-}" == "--force" ]] && FORCE=1

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '    \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '    \033[33m!\033[0m %s\n' "$*"; }

info "Helpers"
mkdir -p "$LOCAL_BIN"
for src in "$REPO_DIR"/bin/*; do
    name="$(basename "$src")"
    dst="$LOCAL_BIN/$name"
    chmod +x "$src"
    if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
        ok "$name already linked"
    elif [[ -e "$dst" && $FORCE -eq 0 ]]; then
        warn "$dst exists and is not a link to this repo — re-run with --force"
    else
        [[ -e "$dst" || -L "$dst" ]] && mv "$dst" "$dst.backup-$(date +%Y%m%d-%H%M%S)"
        ln -s "$src" "$dst"
        ok "linked $name"
    fi
done

info "PATH"
case ":$PATH:" in
    *":$LOCAL_BIN:"*) ok "$LOCAL_BIN is on PATH" ;;
    *) warn "$LOCAL_BIN is not on PATH — add it in your shell rc" ;;
esac

info "Done"
