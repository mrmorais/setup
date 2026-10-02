# Claude Code

My Claude Code setup: global instructions, settings, MCP servers, plugins and
the skill library.

## What's here

```
claude/
├── README.md
├── install.sh
├── config/
│   ├── CLAUDE.md             global instructions, loaded in every session
│   ├── settings.json         template — plugins, hooks, UI
│   ├── settings.local.json   template — machine-local permission allowlist
│   └── mcp-servers.json      template — MCP servers, secrets as ${PLACEHOLDERS}
├── commands/                 personal slash commands
├── skills/                   personal skills (authored here, vendored)
└── skills-external/
    └── skill-lock.json       provenance + pinned hashes for third-party skills
```

> **This repo is public.** Nothing work-related is published here — no internal
> skills, plugins, marketplaces, MCP endpoints, channel or ticket identifiers.
> That part of the setup lives in a private org repo and is installed on top of
> this one. The inventories below are therefore the *public* half of the setup,
> not the whole of it.

## Quick start

```sh
git clone https://github.com/mrmorais/setup.git ~/Projetos/setup
~/Projetos/setup/claude/install.sh
```

---

## Layout on disk

Two directories matter, and the split is the thing worth remembering:

| Path | What lives there |
|---|---|
| `~/.claude/` | everything Claude Code owns — settings, commands, the skill index |
| `~/.agents/` | the **agent-agnostic** skill library, managed by the `skills` CLI |

`~/.claude/skills/` is mostly a directory of **symlinks** into `~/.agents/skills/`,
so one installed copy of a skill is shared across every agent that reads it
(the lockfile currently targets 14 of them — Claude Code, Codex, Cursor, Zed,
opencode, …). Installing a skill once makes it available everywhere.

Three kinds of entry live under `~/.claude/skills/`:

1. **symlink into `~/.agents/skills/`** — installed by `npx skills add`, tracked
   in `skill-lock.json`
2. **real directory** — installed by hand or by a vendor's own installer, *not*
   tracked by the lockfile
3. **symlink to a project checkout** — a skill that is developed inside another
   repo and linked in

---

## Global instructions — `config/CLAUDE.md`

Loaded into every session on every project. Covers the git workflow (branch
before working, commit on every commitable step, never commit on `main`), the
post-implementation loop (CodeRabbit review, then CI checks), and a standing
rule against decorative code comments.

Symlinked by `install.sh` so edits from inside Claude land back in this repo.

## Settings — `config/settings.json`

A **template, not a symlink.** Claude Code rewrites this file when plugins are
enabled or marketplaces are added, so linking it would silently pull private
entries into a public repo. `install.sh` copies it only when there is nothing
there yet, and otherwise just reports the drift.

What it carries:

- **Plugins and marketplaces** — see the table below
- **Hooks** — every lifecycle event (`UserPromptSubmit`, `Stop`, `PostToolUse`,
  `PostToolUseFailure`, `PermissionRequest`, `SessionStart`, `SessionEnd`) pings a
  notifier script. Each hook is guarded on `$SUPERSET_HOME_DIR` being set and the
  script being executable, so on a machine without it they are no-ops.
- **UI/behaviour** — `tui: fullscreen`, agent push notifications on, voice off,
  dangerous-mode and auto-permission prompts skipped
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`

`settings.local.json` is the machine-local permission allowlist (agent-browser,
`obsidian-cli read`, read-only Datadog MCP tools).

## Plugins

| Plugin | Marketplace |
|---|---|
| `ralph-loop` | `anthropics/claude-plugins-official` |
| `code-review` | `anthropics/claude-plugins-official` |
| `kotlin-lsp` | `anthropics/claude-plugins-official` |
| `typescript-lsp` | `anthropics/claude-plugins-official` |
| `mem0` | [`mem0ai/mem0`](https://github.com/mem0ai/mem0) |
| `paper-desktop` | [`paper-design/agent-plugins`](https://github.com/paper-design/agent-plugins) |

`claude-plugins-official` is built in; the other two marketplaces are added by
`install.sh`.

## MCP servers — `config/mcp-servers.json`

User-scope servers. Secrets are **not** in the file — they are `${PLACEHOLDER}`
and must be filled in locally.

| Server | Transport | Needs |
|---|---|---|
| `circleci-mcp-server` | stdio (`npx`) | `CIRCLECI_TOKEN` |
| `chrome-devtools` | stdio (`npx`) | — |
| `pencil` | stdio (local app binary) | Pen.app installed |
| `figma-local` | http `127.0.0.1:3845` | Figma desktop running |
| `datadog-mcp` | http | account auth |
| `mixpanel` | http | account auth |
| `instances-mcp` | http | `INSTANCES_MCP_ENDPOINT_ID` (per-account endpoint) |
| `carpedia` | http | `CARPEDIA_AUTHORIZATION` |

Add them with `claude mcp add-json <name> '<json>'`, or paste the block into
`~/.claude.json` under `mcpServers`.

---

## Skills

### Personal — vendored here

| Skill | What it does |
|---|---|
| [`developer`](skills/developer) | the software development life-cycle: when to request a CodeRabbit review, how to open a PR with `gh`, how to check CI state. `CLAUDE.md` defers to it for the details. |

### Personal commands — vendored here

| Command | What it does |
|---|---|
| [`/loop-address-checks`](commands/loop-address-checks.md) | takes one or more PR URLs (or infers the current branch's PR) and loops until review comments and CI checks are addressed |

### Third-party — referenced, not redistributed

Installed with the [`skills` CLI](https://skills.sh) (`npx skills add`) into
`~/.agents/skills/` and symlinked into every agent directory. `skill-lock.json`
pins the exact content hash of each, and is committed so the same versions can
be restored.

| Source | Count | Skills |
|---|---|---|
| [`mattpocock/skills`](https://github.com/mattpocock/skills) | 30 | `ask-matt`, `caveman`, `code-review`, `codebase-design`, `diagnose`, `diagnosing-bugs`, `domain-modeling`, `grill-me`, `grill-with-docs`, `grilling`, `handoff`, `implement`, `improve-codebase-architecture`, `prd-to-issues`, `prototype`, `research`, `resolving-merge-conflicts`, `setup-matt-pocock-skills`, `tdd`, `teach`, `to-issues`, `to-prd`, `to-spec`, `to-tickets`, `triage`, `wayfinder`, `write-a-prd`, `write-a-skill`, `writing-great-skills`, `zoom-out` |
| [`heygen-com/hyperframes`](https://github.com/heygen-com/hyperframes) | 10 | `hyperframes`, `hyperframes-animation`, `hyperframes-audio`, `hyperframes-cli`, `hyperframes-core`, `hyperframes-creative`, `hyperframes-keyframes`, `hyperframes-registry`, `media-use`, `product-launch-video` |
| [`vercel-labs/agent-browser`](https://github.com/vercel-labs/agent-browser) | 4 | `agent-browser`, `dogfood`, `electron`, `slack` |
| [`anthropics/skills`](https://github.com/anthropics/skills) | 2 | `frontend-design`, `skill-creator` |
| [`figma/mcp-server-guide`](https://github.com/figma/mcp-server-guide) | 2 | `figma-code-connect`, `figma-implement-design` |
| [`GoogleChrome/modern-web-guidance`](https://github.com/GoogleChrome/modern-web-guidance) | 1 | `modern-web-guidance` |
| [`affaan-m/everything-claude-code`](https://github.com/affaan-m/everything-claude-code) | 1 | `jpa-patterns` |
| [`chiroro-jr/pencil-design-skill`](https://github.com/chiroro-jr/pencil-design-skill) | 1 | `pencil-design` |
| [`conorbronsdon/avoid-ai-writing`](https://github.com/conorbronsdon/avoid-ai-writing) | 1 | `avoid-ai-writing` |
| [`github/awesome-copilot`](https://github.com/github/awesome-copilot) | 1 | `chrome-devtools` |
| [`hashicorp/agent-skills`](https://github.com/hashicorp/agent-skills) | 1 | `terraform-style-guide` |
| [`inference-sh/skills`](https://github.com/inference-sh/skills) | 1 | `inference-sh` |
| [`vercel-labs/skills`](https://github.com/vercel-labs/skills) | 1 | `find-skills` |

Reinstall any of them with:

```sh
npx skills add <owner/repo> --global --agent claude-code --skill <name> --yes
```

**Three lockfile entries are stale.** `figma-code-connect` and
`figma-implement-design` (`figma/mcp-server-guide`) and `slack`
(`vercel-labs/agent-browser`) are no longer published by their upstream repos —
`npx skills add` reports "no matching skills found". They were dangling symlinks
locally; `install.sh` clears the broken links, reports what it could not
restore, and moves on. Drop the entries from `skill-lock.json` if you do not
want them retried.

### Installed outside the lockfile

These are real directories under `~/.claude/skills/`, put there by hand or by a
vendor's own installer. The lockfile does not record where they came from, so
reinstalling means finding the upstream again:

- **Cloudflare set** — `cloudflare`, `agents-sdk`, `cloudflare-email-service`,
  `cloudflare-one`, `cloudflare-one-migrations`, `durable-objects`,
  `sandbox-sdk`, `turnstile-spin`, `web-perf`, `workers-best-practices`,
  `wrangler`
- `graphify`, `session-reflect`
- `first-mate` — sits in `~/.agents/skills/` but has no lockfile entry
- `deep-review` — symlinked from a local checkout at `~/pr-review-skill/`

`install.sh` does not try to install these; it lists what is missing and leaves
it to you.

---

## Reproducing on a new machine

1. Install Claude Code and Node (the `skills` CLI needs Node ≥ 22.20)
2. Clone this repo and run `claude/install.sh`
3. Fill in the MCP secrets — the script tells you which are still placeholders
4. Install the private org layer separately, if this is a work machine

## Keeping it in sync

`CLAUDE.md`, `commands/` and `skills/` are symlinked, so editing them from
inside Claude edits this repo.

`settings.json`, `settings.local.json` and `mcp-servers.json` are **copies**,
on purpose — Claude Code rewrites the first two, and the third would otherwise
carry live credentials. When one of them changes meaningfully, re-sanitise and
copy it back by hand:

```sh
claude/install.sh --diff    # show how the live files have drifted from the repo
```

Expect `--diff` to report drift on `settings.json` on a work machine: the
private plugins and marketplace are enabled live and deliberately absent from
the repo copy. That gap is the point, not a bug — just never paste the diff
anywhere public.

Refresh the third-party skill provenance with:

```sh
cp ~/.agents/.skill-lock.json claude/skills-external/skill-lock.json
```
