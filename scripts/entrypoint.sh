#!/bin/sh
set -eu

# Bring up WireGuard tunnels mounted at /etc/wireguard/. This file
# replaces the base entrypoint at the same path, so the bring-up
# that the base image performs has to be re-invoked here.
if [ -x /usr/local/bin/wg-up.sh ]; then
    /usr/local/bin/wg-up.sh || true
fi

# Wire GITHUB_TOKEN as HTTPS credential helper for git pull/push.
if [ -n "${GITHUB_TOKEN:-}" ]; then
    git config --global credential.helper store
    printf 'https://x-access-token:%s@github.com\n' "$GITHUB_TOKEN" > "$HOME/.git-credentials"
    chmod 600 "$HOME/.git-credentials"
fi

# Install starter ~/.claude/CLAUDE.md if the user doesn't have one yet.
# Pre-existing files (e.g. on a bind-mounted ~/.claude) are left alone
# so operator customizations survive container restarts.
if [ -f /etc/claude-code/CLAUDE.md.starter ] && [ ! -f "$HOME/.claude/CLAUDE.md" ]; then
    mkdir -p "$HOME/.claude"
    cp /etc/claude-code/CLAUDE.md.starter "$HOME/.claude/CLAUDE.md"
    chmod 644 "$HOME/.claude/CLAUDE.md"
fi

# Assemble ~/.claude.json from /etc/claude-code/claude.d/ fragments.
if [ -x /usr/local/bin/merge-claude-config.sh ]; then
    /usr/local/bin/merge-claude-config.sh
fi

exec "$@"
