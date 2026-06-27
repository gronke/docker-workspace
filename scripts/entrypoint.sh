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

# Assemble Claude Code config from claude.d drop-ins (baked defaults
# plus any overrides mounted at /etc/claude-code/claude.d.local).
if command -v claude-config-builder >/dev/null 2>&1; then
    claude-config-builder apply
fi

exec "$@"
