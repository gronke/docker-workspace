# claude.d — Claude Code drop-in configuration

`claude.d` is a stackable, ordered drop-in tree assembled by [`claude-config-builder`](../scripts/claude-config-builder).
It is the single source for the image's Claude Code configuration — nothing else in the image writes `~/.claude.json`, `~/.claude/settings.json`, or `~/.claude/CLAUDE.md` directly.

## Entry kinds

Entries process in `LC_ALL=C` order **by basename**, unioned across every directory on the search path (`CLAUDE_CONFIG_PATH`, default `/etc/claude-code/claude.d:/etc/claude-code/claude.d.local`; later directory wins on a basename collision):

| Entry | Goes to |
|-------|---------|
| `NNNN-name.json` (flat file) | merged into `~/.claude.json` (the default target) |
| `NNNN-name.json.tpl` (flat) | `envsubst` first, then merged into `~/.claude.json` |
| `[NNNN-]<dest>.json/` (directory) | its `*.json[.tpl]` children merged into `<dest>`: `claude.json` → `~/.claude.json`, `settings.json` → `~/.claude/settings.json` |
| `[NNNN-]CLAUDE.md` (flat file) | concatenated into `~/.claude/CLAUDE.md` (a `.tpl` variant is `envsubst`'d first); a fragment is any file whose name ends in `CLAUDE.md`, so `README.md` is never one |
| `NNNN-name.sh` (hook) | sourced into the shell — sets aliases, exports env, runs setup. Branches on `$CLAUDE_CONFIG_PHASE` (`apply` \| `shellenv`). |

JSON merge is a recursive object merge (`jq '.[0] * .[1]'`); **arrays are replaced** (last writer wins per key), so don't split an array across fragments.
Each JSON target is seeded from its existing file, so re-running is idempotent and preserves edits made on top.

The markdown target is different.
Fragments are **concatenated** in basename order (never merged), and `~/.claude/CLAUDE.md` is **regenerated from scratch on every `apply`** — so it always reflects the fragments, and manual edits to it (including Claude's own `# memory` appends) do not survive.
Add a `[NNNN-]CLAUDE.md` fragment instead, or keep project-specific notes in a project-level `CLAUDE.md`.
Fragments layer by basename like every other entry — a later search-dir fragment with the same name overrides, a new name appends.
The generated file opens with a generic `<!-- CUSTOM -->` marker — it deliberately says nothing about how the file is assembled, so the agent reading it needn't reason about its configuration.

**Which key goes where matters.**
Claude Code reads `model`, `effortLevel`, `permissions`, `env`, `hooks` **only** from the `settings.json` family, and `theme`, `tui`, `hasCompletedOnboarding`, `mcpServers` from `~/.claude.json`.
Put each key in a fragment whose target is the file Claude actually reads it from.

## Modes

- `claude-config-builder apply` — assemble the JSON + markdown targets and run `apply`-phase hooks.
  Run once at container start (by the entrypoint).
- `claude-config-builder shellenv` — emit `. <hook>` lines for the shell to `eval` (`shellenv` phase).
  Wired into `/etc/bash.bashrc` via `eval "$(claude-config-builder shellenv)"`.

## This directory (baked defaults)

| Entry | Purpose |
|-------|---------|
| `0010-CLAUDE.md` | base instructions → `~/.claude/CLAUDE.md` (concatenated, regenerated each apply) |
| `0090-CLAUDE.md` | extra: do not push to public repos → `~/.claude/CLAUDE.md` |
| `0010-claude.json/onboarding.json` | theme, onboarding flags → `~/.claude.json` |
| `0010-settings.json/defaults.json` | default model / effort / permissions → `~/.claude/settings.json` (overridable) |
| `0040-github-mcp.json` | hosted GitHub MCP server; `${GITHUB_TOKEN}` stays literal in the merged file and is expanded by Claude Code at read time |
| `0050-claude-args.sh` | define the interactive `claude` launch alias (appends `$CLAUDE_ARGS`) |

Operator- or infrastructure-specific overrides layer in from a directory mounted read-only at `/etc/claude-code/claude.d.local`.

> The loader is project-agnostic so it and this contract can later move into a standalone `claude-config-builder` repo.
