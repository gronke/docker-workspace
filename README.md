# docker-workspace

Layered Docker images for generic dev work environments — a bootstrap repo for typical Claude Code workflows.

## Images

### Base (`workspace-base`)

Debian with `en_US.UTF-8` locale, UTC timezone, and common tools:

vim, tmux, netcat-openbsd, curl, nmap, socat, iproute2, dnsutils, iputils-ping, less, file, jq, ripgrep, sudo, git, gettext-base, openssh-client

Runs as user `dev` (passwordless sudo) with working directory `/mnt`.

### Claude (`workspace-claude`)

Extends base with a pre-configured [Claude Code](https://claude.ai/code) installation. Configuration is assembled at container start from JSON fragments in `claude.d/` (theme, onboarding-skip, MCP servers with runtime-substituted tokens). The shell alias `claude='claude --model "opus[1m]" --effort max'` is set in `~/.bashrc` for the `dev` user.

## Build

```sh
# Base image (required)
docker build -f Dockerfile.base -t workspace-base .

# Claude layer (optional, requires base)
docker build -f Dockerfile.claude -t workspace-claude .
```

## Usage

### Base

```sh
docker run -it -v "$(pwd)":/mnt workspace-base
```

### Claude

```sh
docker run -it \
  -e CLAUDE_CODE_OAUTH_TOKEN="$CLAUDE_CODE_OAUTH_TOKEN" \
  -e GITHUB_TOKEN="$GITHUB_TOKEN" \
  -e GHCR_TOKEN="$GHCR_TOKEN" \
  -e GIT_USER_NAME="$(git config --global user.name)" \
  -e GIT_USER_EMAIL="$(git config --global user.email)" \
  -v "$HOME/.ssh:/home/dev/.ssh:ro" \
  -v "$(pwd)":/mnt \
  workspace-claude
```

Then run `claude` inside the container.

### Environment variables

| Variable | Purpose | Token type |
|---|---|---|
| `CLAUDE_CODE_OAUTH_TOKEN` | Authenticates Claude Code. | — |
| `GITHUB_TOKEN` | `git` HTTPS pull/push (credential helper) **and** the hosted GitHub MCP server (`https://api.githubcopilot.com/mcp`) via `Authorization: Bearer`. | **Fine-grained PAT** with repo content r/w on the repos you need. |
| `GHCR_TOKEN` | GHCR auth for `oras`, `helm pull oci://ghcr.io/...`, future `docker login ghcr.io` etc. Just exported as env — no active wiring inside the container yet. | **Classic PAT** with `read:packages` (+ `write:packages` to push). GHCR doesn't accept fine-grained PATs. |
| `GIT_USER_NAME`, `GIT_USER_EMAIL` | Convenience pair. The `dev` shell rc derives `GIT_AUTHOR_*` and `GIT_COMMITTER_*` from these and seeds `git config --global user.name/user.email`. | — |
| `GIT_AUTHOR_NAME` / `GIT_AUTHOR_EMAIL` / `GIT_COMMITTER_NAME` / `GIT_COMMITTER_EMAIL` | Optional, for split author/committer identities. When set, override the values derived from `GIT_USER_*`. | — |

The optional `-v ~/.ssh:/home/dev/.ssh:ro` mount lets you push/pull via SSH-based git remotes using existing host keys.

## claude.d — configuration fragments

Claude Code settings live in JSON fragments under `/etc/claude-code/claude.d/` and are deep-merged into `~/.claude.json` at container start by `scripts/merge-claude-config.sh`:

- `00-defaults.json` — shipped with the image (theme, onboarding-skip, model, permissions)
- `40-github-mcp.json` — GitHub MCP via the hosted endpoint (`api.githubcopilot.com/mcp`). The header value is `"Bearer ${GITHUB_TOKEN}"` *literally* — Claude Code expands `${…}` references in `mcpServers.*.{command,args,env,url,headers}` at read time, so the token never persists in `~/.claude.json`.
- `50-*.json` / `50-*.json.tpl` — additional server/infra-provided fragments (e.g. mounted via `-v` from a sibling `infrastructure` repo). `.json.tpl` files run through `envsubst` *at container start*, useful when something other than Claude itself reads the file.
- `90-*.json` — user overrides (highest priority)

**File extension matters:** `.json` is merged as-is (good for MCP configs — Claude expands `${…}` natively). `.json.tpl` is processed through `envsubst` at startup (use when the consumer doesn't do its own expansion).

## Structure

```
claude.d/          Claude Code config fragments (deep-merged at startup)
scripts/           merge-claude-config.sh + entrypoint.sh
dotfiles/          Dotfiles copied into /home/dev/
Dockerfile.base    Debian base layer
Dockerfile.claude  Claude Code layer
```
