# docker-workspace

Layered Docker images for generic dev work environments.

## Images

### Base (`workspace-base`)

Debian with `en_US.UTF-8` locale, UTC timezone, and common tools:

vim, tmux, netcat-openbsd, curl, nmap, socat, iproute2, dnsutils, iputils-ping, less, file, jq, ripgrep, sudo

Runs as user `dev` (passwordless sudo) with working directory `/mnt`.

### Claude (`workspace-claude`)

Extends base with a pre-configured [Claude Code](https://claude.ai/code) installation (Opus, max effort, all common tools allowed).

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
  -v "$(pwd)":/mnt \
  workspace-claude
```

Then run `claude` inside the container.

## Structure

```
dotfiles/          Dotfiles copied into /home/dev/
claude/            Pre-built ~/.claude/ config for the claude layer
Dockerfile.base    Debian base layer
Dockerfile.claude  Claude Code layer
```
