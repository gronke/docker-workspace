#!/bin/sh
set -eu

# Wire GITHUB_TOKEN as HTTPS credential helper for git pull/push.
if [ -n "${GITHUB_TOKEN:-}" ]; then
    git config --global credential.helper store
    printf 'https://x-access-token:%s@github.com\n' "$GITHUB_TOKEN" > "$HOME/.git-credentials"
    chmod 600 "$HOME/.git-credentials"
fi

# Assemble ~/.claude.json from /etc/claude-code/claude.d/ fragments.
if [ -x /usr/local/bin/merge-claude-config.sh ]; then
    /usr/local/bin/merge-claude-config.sh
fi

exec "$@"
