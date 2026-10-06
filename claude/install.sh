#!/usr/bin/env bash
#
# Bootstrap the Claude Code setup.
#
# Symlinks what is safe to link (CLAUDE.md, personal commands and skills),
# copies the config templates only when nothing is there yet, adds the plugin
# marketplaces, and restores the third-party skills from the lockfile.
#
# Idempotent. Nothing is overwritten without --force.
#
# Usage:
#   claude/install.sh           install what is missing
#   claude/install.sh --force   also replace existing links and config files
#   claude/install.sh --diff    only report how the live config has drifted

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
AGENTS_DIR="$HOME/.agents"
LOCK="$REPO_DIR/skills-external/skill-lock.json"
MODE="install"
case "${1:-}" in
    --force) MODE="force" ;;
    --diff)  MODE="diff" ;;
esac

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '    \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '    \033[33m!\033[0m %s\n' "$*"; }

have() { command -v "$1" >/dev/null 2>&1; }

# link <source-in-repo> <destination>
link() {
    local src="$1" dst="$2" name="${2##*/}"
    if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
        ok "$name already linked"
    elif [[ -e "$dst" && "$MODE" != "force" ]]; then
        warn "$dst exists and is not a link to this repo — re-run with --force"
    else
        mkdir -p "$(dirname "$dst")"
        [[ -e "$dst" || -L "$dst" ]] && mv "$dst" "$dst.backup-$(date +%Y%m%d-%H%M%S)"
        ln -s "$src" "$dst"
        ok "linked $name"
    fi
}

# ---------------------------------------------------------------------------
# --diff: report drift and stop
#
# The three config templates are copies, not links, so they go stale silently.
# ---------------------------------------------------------------------------

if [[ "$MODE" == "diff" ]]; then
    info "Config drift (repo → live)"
    for pair in "config/settings.json:$CLAUDE_DIR/settings.json" \
                "config/settings.local.json:$CLAUDE_DIR/settings.local.json"; do
        repo="$REPO_DIR/${pair%%:*}" live="${pair#*:}"
        if diff -q "$repo" "$live" >/dev/null 2>&1; then
            ok "${pair%%:*} in sync"
        else
            warn "${pair%%:*} differs:"
            diff -u "$repo" "$live" | sed 's/^/        /' || true
        fi
    done
    warn "mcp-servers.json is a redacted template — compare it by hand against ~/.claude.json"
    if [[ -f "$AGENTS_DIR/.skill-lock.json" ]]; then
        diff -q "$LOCK" "$AGENTS_DIR/.skill-lock.json" >/dev/null 2>&1 \
            && ok "skill-lock.json in sync" \
            || warn "skill-lock.json differs — refresh with: cp ~/.agents/.skill-lock.json $LOCK"
    fi
    exit 0
fi

# ---------------------------------------------------------------------------
# Prerequisites
# ---------------------------------------------------------------------------

info "Prerequisites"
have claude && ok "claude $(claude --version 2>/dev/null | head -1)" \
            || { warn "claude not found — install Claude Code first"; exit 1; }
if have node; then
    node_major="$(node -v | sed 's/^v\([0-9]*\).*/\1/')"
    node_minor="$(node -v | sed 's/^v[0-9]*\.\([0-9]*\).*/\1/')"
    if (( node_major > 22 || (node_major == 22 && node_minor >= 20) )); then
        ok "node $(node -v)"
    else
        warn "node $(node -v) — the skills CLI wants >= 22.20, skill install may warn"
    fi
else
    warn "node not found — third-party skills cannot be installed"
fi

# ---------------------------------------------------------------------------
# Global instructions, personal commands and skills — symlinked
# ---------------------------------------------------------------------------

info "Global instructions"
link "$REPO_DIR/config/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"

info "Personal commands"
for f in "$REPO_DIR"/commands/*.md; do
    link "$f" "$CLAUDE_DIR/commands/$(basename "$f")"
done

info "Personal skills"
for d in "$REPO_DIR"/skills/*/; do
    link "${d%/}" "$CLAUDE_DIR/skills/$(basename "${d%/}")"
done

# ---------------------------------------------------------------------------
# Config templates — copied, never linked
#
# Claude Code rewrites settings.json as plugins are enabled, and mcp-servers.json
# would otherwise end up holding live credentials. Linking either one would push
# private state into a public repo.
# ---------------------------------------------------------------------------

info "Config templates"
for name in settings.json settings.local.json; do
    src="$REPO_DIR/config/$name" dst="$CLAUDE_DIR/$name"
    if [[ ! -e "$dst" ]]; then
        cp "$src" "$dst"
        ok "installed $name"
    elif diff -q "$src" "$dst" >/dev/null 2>&1; then
        ok "$name matches the repo"
    elif [[ "$MODE" == "force" ]]; then
        cp "$dst" "$dst.backup-$(date +%Y%m%d-%H%M%S)"
        cp "$src" "$dst"
        ok "replaced $name (backup kept)"
    else
        warn "$name differs from the repo — see: $0 --diff"
    fi
done

# ---------------------------------------------------------------------------
# MCP servers
# ---------------------------------------------------------------------------

info "MCP servers"
if have python3; then
    python3 - "$REPO_DIR/config/mcp-servers.json" <<'PY'
import json, os, re, subprocess, sys

template = json.load(open(sys.argv[1]))["mcpServers"]
live_path = os.path.expanduser("~/.claude.json")
live = json.load(open(live_path)).get("mcpServers", {}) if os.path.exists(live_path) else {}

placeholder = re.compile(r"\$\{[A-Z0-9_]+\}")
for name, cfg in template.items():
    if name in live:
        print(f"    \033[32m✓\033[0m {name} already configured")
        continue
    missing = placeholder.findall(json.dumps(cfg))
    if missing:
        print(f"    \033[33m!\033[0m {name} needs {', '.join(sorted(set(missing)))} "
              f"— fill in and run: claude mcp add-json {name} '<json>'")
    else:
        subprocess.run(["claude", "mcp", "add-json", "--scope", "user",
                        name, json.dumps(cfg)], check=False)
        print(f"    \033[32m✓\033[0m added {name}")
PY
else
    warn "python3 not found — add the servers from config/mcp-servers.json by hand"
fi

# ---------------------------------------------------------------------------
# Plugin marketplaces
# ---------------------------------------------------------------------------

info "Plugin marketplaces"
known="$(claude plugin marketplace list 2>/dev/null || true)"
for mp in "mem0ai/mem0" "https://github.com/paper-design/agent-plugins.git"; do
    short="${mp##*/}"
    if grep -qi "${short%.git}" <<<"$known"; then
        ok "${short%.git} already added"
    else
        claude plugin marketplace add "$mp" >/dev/null 2>&1 \
            && ok "added ${short%.git}" \
            || warn "could not add $mp — add it from /plugin inside Claude"
    fi
done

info "Plugins"
installed="$(claude plugin list 2>/dev/null || true)"
for plugin in ralph-loop@claude-plugins-official \
              code-review@claude-plugins-official \
              kotlin-lsp@claude-plugins-official \
              typescript-lsp@claude-plugins-official \
              mem0@mem0-plugins \
              paper-desktop@paper; do
    if grep -q "${plugin%%@*}" <<<"$installed"; then
        ok "${plugin%%@*} already installed"
    else
        claude plugin install "$plugin" >/dev/null 2>&1 \
            && ok "installed ${plugin%%@*}" \
            || warn "could not install $plugin"
    fi
done

# ---------------------------------------------------------------------------
# Third-party skills
#
# Restored from the lockfile with the skills CLI, which installs into
# ~/.agents/skills and symlinks into every agent directory.
# ---------------------------------------------------------------------------

info "Third-party skills"
if ! have node; then
    warn "skipped - node is required"
elif [[ ! -f "$LOCK" ]]; then
    warn "skipped - $LOCK is missing"
else
    python3 - "$LOCK" "$CLAUDE_DIR/skills" "$AGENTS_DIR/skills" <<'SKILLS'
import json, os, subprocess, sys

GREEN, YELLOW, RESET = "\033[32m", "\033[33m", "\033[0m"
def ok(msg):   print(f"    {GREEN}\u2713{RESET} {msg}")
def warn(msg): print(f"    {YELLOW}!{RESET} {msg}")

lock = json.load(open(sys.argv[1]))["skills"]
roots = sys.argv[2:]

def installed(name):
    """True if NAME resolves under any agent root.

    The CLI installs either as a symlink into ~/.agents/skills or as a copy
    straight into the agent directory, so both roots are checked. A dangling
    symlink resolves to nothing and counts as absent."""
    return any(os.path.exists(os.path.join(root, name)) for root in roots)

def clear_dangling(name):
    """Drop a broken symlink so the CLI has somewhere to write."""
    for root in roots:
        path = os.path.join(root, name)
        if os.path.islink(path) and not os.path.exists(path):
            os.unlink(path)

missing = {}
for name, meta in lock.items():
    if not installed(name):
        missing.setdefault(meta["source"], []).append(name)

if not missing:
    ok(f"all {len(lock)} skills from the lockfile are installed")
    raise SystemExit

for source, names in sorted(missing.items()):
    names.sort()
    print(f"    installing {', '.join(names)} from {source}")
    for name in names:
        clear_dangling(name)
    result = subprocess.run(
        ["npx", "-y", "skills@latest", "add", source, "--global",
         "--agent", "claude-code", "--skill", ",".join(names), "--yes"],
        capture_output=True, text=True)
    still = [n for n in names if not installed(n)]
    if still:
        warn(f"{', '.join(still)} still missing - install by hand:")
        warn(f"  npx skills add {source} -g -a claude-code -s {','.join(still)} -y")
        if result.returncode != 0:
            warn(f"  the CLI exited {result.returncode}")
    else:
        ok(f"installed {', '.join(names)}")
SKILLS
fi

# ---------------------------------------------------------------------------

info "Done"
cat <<'EOF'

    Not handled by this script:

      - Skills installed outside the lockfile (the Cloudflare set, graphify,
        session-reflect, first-mate, deep-review) — see the README.
      - The private org layer: internal skills, plugins and MCP servers are
        deliberately not in this public repo.

    Check for config drift at any time with:  claude/install.sh --diff
EOF
