# docker-workspace

Layered Docker images for generic dev work environments — a bootstrap repo for typical Claude Code workflows.

## Images

### Base (`workspace-base`)

Debian with `en_US.UTF-8` locale, UTC timezone, and common tools:

vim, tmux, netcat-openbsd, curl, nmap, socat, iproute2, dnsutils, iputils-ping, less, file, jq, ripgrep, sudo, git, gettext-base, openssh-client

Plus ops tooling (`sops`, `age`, `age-keygen`) for editing SOPS-encrypted vault files in mounted repos. Versions are pinned via build args (`SOPS_VERSION`, `AGE_VERSION`) — override at build time when bumping. Defaults track `infrastructure/Dockerfile.sops` in the infrastructure repo.

Runs as user `dev` (passwordless sudo) with working directory `/mnt`.

### Claude (`workspace-claude`)

Extends base with a pre-configured Claude Code installation. Configuration is assembled at container start by `claude-config-builder` from drop-in fragments in `claude.d/`: theme and onboarding-skip into `~/.claude.json`, model/effort/permissions into `~/.claude/settings.json`, MCP servers with runtime-expanded tokens. An interactive `claude` alias appends `$CLAUDE_ARGS` for session flags; operator overrides mount at `/etc/claude-code/claude.d.local`.

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

### WireGuard

The base image ships `wireguard-tools`. At container start, every `*.conf` under `/etc/wireguard/` is brought up via `wg-quick`; failures are logged but non-fatal, and re-running the entrypoint skips interfaces already up.

```sh
docker run -it \
  --cap-add=NET_ADMIN \
  -v /path/to/wg-configs:/etc/wireguard:ro \
  -v "$(pwd)":/mnt \
  workspace-base
```

Requirements and knobs:

- **Host kernel must support WireGuard.** Linux ≥ 5.6 has it built in; on older kernels run `modprobe wireguard` on the host. The container does not load kernel modules.
- `--cap-add=NET_ADMIN` is required for `ip link add ... type wireguard`.
- `--sysctl net.ipv4.conf.all.src_valid_mark=1` is sometimes needed when the host default-route policy differs from the tunnel's `AllowedIPs`.
- `-e WG_AUTOSTART=0` skips bring-up entirely (also accepts `false`, `no`, `off`).

## claude.d — configuration fragments

Claude Code configuration lives in an ordered drop-in tree assembled by `scripts/claude-config-builder` — once at container start (`claude-config-builder apply`, run by the entrypoint) and per interactive shell (`eval "$(claude-config-builder shellenv)"` in `/etc/bash.bashrc`).

Entries process in `LC_ALL=C` order by basename, unioned across the search path (`CLAUDE_CONFIG_PATH`, default `/etc/claude-code/claude.d:/etc/claude-code/claude.d.local`). On a basename collision the later directory wins, so a mounted override replaces the baked fragment of the same name.

| Entry | Goes to |
|---|---|
| `NNNN-name.json` (flat file) | merged into `~/.claude.json` (default target) |
| `NNNN-name.json.tpl` (flat file) | `envsubst` first, then merged into `~/.claude.json` |
| `[NNNN-]claude.json/` (directory) | its `*.json[.tpl]` children merged into `~/.claude.json` |
| `[NNNN-]settings.json/` (directory) | its `*.json[.tpl]` children merged into `~/.claude/settings.json` |
| `NNNN-name.sh` (hook) | sourced; branches on `$CLAUDE_CONFIG_PHASE` (`apply` at start \| `shellenv` per shell) |

JSON merge is a recursive object merge (`jq '.[0] * .[1]'`); **arrays are replaced**, not concatenated — don't split an array across fragments. Targets are seeded from their existing files, so re-running is idempotent and preserves edits made on top. Claude Code reads `model`, `effortLevel`, `permissions`, `env`, `hooks` only from `~/.claude/settings.json`, and `theme`, `hasCompletedOnboarding`, `mcpServers` from `~/.claude.json` — put each key in a fragment targeting the file Claude actually reads it from.

Shipped fragments:

- `0010-claude.json/onboarding.json` — theme, onboarding-skip
- `0010-settings.json/defaults.json` — default model, effort, permissions
- `0040-github-mcp.json` — GitHub MCP via the hosted endpoint (`api.githubcopilot.com/mcp`). The header value is `"Bearer ${GITHUB_TOKEN}"` *literally* — Claude Code expands `${…}` references in `mcpServers.*.{command,args,env,url,headers}` at read time, so the token never persists in `~/.claude.json`.
- `0050-claude-args.sh` — interactive `claude` alias appending `$CLAUDE_ARGS` (session flags; model/effort come from settings.json)

**Overrides:** mount a fragment directory read-only at `/etc/claude-code/claude.d.local` (e.g. from a sibling infrastructure repo):

```sh
docker run -it \
  -v /path/to/claude.d:/etc/claude-code/claude.d.local:ro \
  ... \
  workspace-claude
```

Flat fragments from the previous single-target layout keep working (they merge into `~/.claude.json`); mount override *directories* at `claude.d.local` instead of injecting files into the baked `claude.d/`.

**File extension matters:** `.json` is merged as-is (good for MCP configs — Claude expands `${…}` natively). `.json.tpl` is processed through `envsubst` at assembly time (use when the consumer doesn't do its own expansion).

The full contract is documented in [`claude.d/README.md`](claude.d/README.md).

## Structure

```
claude.d/          Claude Code config fragments (assembled at startup + per shell)
scripts/           claude-config-builder + entrypoint scripts
dotfiles/          Dotfiles copied into /home/dev/
Dockerfile.base    Debian base layer
Dockerfile.claude  Claude Code layer
```
