#!/usr/bin/env bash
#
# Bootstrap the Emacs setup on a fresh macOS or Linux (Ubuntu) machine.
#
# Idempotent: every step checks for what it installs and skips if present.
# Re-run it after pulling this repo to pick up anything new.
#
# Usage:
#   emacs/install.sh            install everything that is missing
#   emacs/install.sh --force    also replace existing ~/.emacs.d config files

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EMACS_D="$HOME/.emacs.d"
LOCAL_SHARE="$HOME/.local/share"
LOCAL_BIN="$HOME/.local/bin"
FORCE=0
[[ "${1:-}" == "--force" ]] && FORCE=1

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '    \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '    \033[33m!\033[0m %s\n' "$*"; }

have() { command -v "$1" >/dev/null 2>&1; }

OS="$(uname -s)"
ARCH="$(uname -m)"

# ---------------------------------------------------------------------------
# Emacs
# ---------------------------------------------------------------------------

info "Emacs"
if [[ -d /Applications/Emacs.app ]] || have emacs; then
    ok "already installed ($(emacs --version 2>/dev/null | head -1))"
elif [[ "$OS" == Darwin ]] && have brew; then
    brew install --cask emacs-app
elif [[ "$OS" == Darwin ]]; then
    warn "Homebrew not found — install it from https://brew.sh then re-run"
    exit 1
else
    warn "not found — run: sudo snap install emacs --classic   (then re-run)"
    exit 1
fi

# ---------------------------------------------------------------------------
# Config files
#
# Symlinked rather than copied so edits made inside Emacs land in this repo.
# ---------------------------------------------------------------------------

info "Config files"
mkdir -p "$EMACS_D"
for file in init.el custom.el; do
    src="$REPO_DIR/emacs.d/$file"
    dst="$EMACS_D/$file"
    if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
        ok "$file already linked"
    elif [[ -e "$dst" && $FORCE -eq 0 ]]; then
        warn "$dst exists and is not a link to this repo — re-run with --force to replace"
    else
        [[ -e "$dst" || -L "$dst" ]] && mv "$dst" "$dst.backup-$(date +%Y%m%d-%H%M%S)"
        ln -s "$src" "$dst"
        ok "linked $file"
    fi
done

# ---------------------------------------------------------------------------
# C / C++ — clangd ships with the Xcode command line tools on macOS,
# and comes from apt on Linux
# ---------------------------------------------------------------------------

info "clangd (C/C++)"
if have clangd; then
    ok "$(command -v clangd)"
elif [[ "$OS" == Darwin ]]; then
    warn "not found — run: xcode-select --install"
else
    warn "not found — run: sudo apt install clangd cmake"
fi

# ---------------------------------------------------------------------------
# Java — Eclipse JDT Language Server
# ---------------------------------------------------------------------------

info "jdtls (Java)"
JDTLS_URL="https://download.eclipse.org/jdtls/snapshots/jdt-language-server-latest.tar.gz"
if [[ -x "$LOCAL_SHARE/jdtls/bin/jdtls" ]]; then
    ok "already installed"
else
    mkdir -p "$LOCAL_SHARE/jdtls" "$LOCAL_BIN"
    tmp="$(mktemp -d)"
    curl -fsSL "$JDTLS_URL" -o "$tmp/jdtls.tar.gz"
    tar -xzf "$tmp/jdtls.tar.gz" -C "$LOCAL_SHARE/jdtls"
    rm -rf "$tmp"
    ln -sf "$LOCAL_SHARE/jdtls/bin/jdtls" "$LOCAL_BIN/jdtls"
    ok "installed to $LOCAL_SHARE/jdtls"
fi

# jdtls will not start below JDK 21; init.el launches it with 25, falling back to 21.
if [[ -d "$HOME/.sdkman/candidates/java" ]]; then
    found="$(ls "$HOME/.sdkman/candidates/java" | grep -E '^(21|25)\.' || true)"
    if [[ -n "$found" ]]; then
        ok "JDK for the language server: $(echo "$found" | tail -1)"
    else
        warn "no JDK 21+ under ~/.sdkman — run: sdk install java 25.0.4-amzn"
    fi
else
    warn "SDKMAN not found — install from https://sdkman.io then: sdk install java 25.0.4-amzn"
fi

# ---------------------------------------------------------------------------
# Kotlin — JetBrains kotlin-lsp
# ---------------------------------------------------------------------------

info "kotlin-lsp (Kotlin)"
if [[ -x "$LOCAL_SHARE/kotlin-lsp/bin/intellij-server" ]]; then
    ok "already installed (build $(cat "$LOCAL_SHARE/kotlin-lsp/build.txt" 2>/dev/null))"
else
    # The GitHub release has no binary assets; the standalone archives are
    # linked from the release notes, one per platform.
    case "$OS-$ARCH" in
        Darwin-arm64)  pattern='kotlin-server-[0-9.]*-aarch64\.sit' ;;
        Darwin-x86_64) pattern='kotlin-server-[0-9.]*\.sit' ;;
        Linux-aarch64) pattern='kotlin-server-[0-9.]*-aarch64\.tar\.gz' ;;
        Linux-x86_64)  pattern='kotlin-server-[0-9.]*\.tar\.gz' ;;
        *)             pattern='' ;;
    esac
    asset=""
    if [[ -n "$pattern" ]]; then
        asset="$(curl -fsSL https://api.github.com/repos/Kotlin/kotlin-lsp/releases/latest \
                 | grep -o "https://download\.jetbrains\.com/[^)\"]*/$pattern" | head -1 || true)"
    fi
    if [[ -z "$asset" ]]; then
        warn "could not resolve a release asset — download manually from"
        warn "https://github.com/Kotlin/kotlin-lsp/releases into $LOCAL_SHARE/kotlin-lsp"
    else
        mkdir -p "$LOCAL_SHARE/kotlin-lsp" "$LOCAL_BIN"
        tmp="$(mktemp -d)"
        curl -fsSL "$asset" -o "$tmp/kotlin-lsp.archive"
        if [[ "$asset" == *.tar.gz ]]; then
            tar -xzf "$tmp/kotlin-lsp.archive" -C "$LOCAL_SHARE/kotlin-lsp"
        else
            unzip -q "$tmp/kotlin-lsp.archive" -d "$LOCAL_SHARE/kotlin-lsp"
        fi
        rm -rf "$tmp"
        # Archives may wrap everything in a single top-level directory.
        if [[ ! -e "$LOCAL_SHARE/kotlin-lsp/bin" ]]; then
            inner="$(find "$LOCAL_SHARE/kotlin-lsp" -mindepth 2 -maxdepth 2 -type d -name bin | head -1)"
            [[ -n "$inner" ]] && { shopt -s dotglob; mv "$(dirname "$inner")"/* "$LOCAL_SHARE/kotlin-lsp/"; rmdir "$(dirname "$inner")"; shopt -u dotglob; }
        fi
        chmod +x "$LOCAL_SHARE/kotlin-lsp/bin/intellij-server"
        ln -sf "$LOCAL_SHARE/kotlin-lsp/bin/intellij-server" "$LOCAL_BIN/kotlin-lsp"
        ok "installed to $LOCAL_SHARE/kotlin-lsp"
    fi
fi

# ---------------------------------------------------------------------------
# JavaScript / TypeScript
#
# Fallback server for projects pinning TypeScript < 7. Projects on 7+ use their
# own node_modules/.bin/tsc --lsp.
# ---------------------------------------------------------------------------

info "typescript-language-server (JS/TS)"
if [[ -x "$LOCAL_BIN/typescript-language-server" ]]; then
    ok "already installed ($("$LOCAL_BIN/typescript-language-server" --version 2>/dev/null))"
elif have npm; then
    npm install --silent --prefix "$HOME/.local" -g typescript typescript-language-server
    ok "installed to $HOME/.local"
else
    warn "npm not found — install Node (https://github.com/nvm-sh/nvm) then re-run"
fi

# ---------------------------------------------------------------------------

info "Done"
cat <<'EOF'

    Next steps:
      1. Launch Emacs — ELPA packages install themselves on first startup.
      2. Run  M-x mm/treesit-install-missing  to compile the tree-sitter grammars.

    Make sure ~/.local/bin is on your PATH.
EOF
