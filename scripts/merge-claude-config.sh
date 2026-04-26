#!/bin/sh
# merge-claude-config.sh — Assemble Claude Code config from fragments.
#
# Scans /etc/claude-code/claude.d/ for JSON fragments (sorted numerically),
# deep-merges all into ~/.claude.json.
#
# Supports two file types:
#   *.json     — static fragments, merged as-is
#   *.json.tpl — template fragments, processed through envsubst first
#                (allows ${ENV_VAR} references for runtime tokens)
#
# If ~/.claude.json already exists it is loaded first as the lowest-priority
# base.  Fragments are applied in sorted filename order (00- first, 99- last).
#
# Requires: jq, envsubst (gettext-base)
# Idempotent — safe to re-run.

set -eu

CLAUDE_D="/etc/claude-code/claude.d"
TARGET="$HOME/.claude.json"

# Start with existing config or empty object.
if [ -f "$TARGET" ]; then
    config=$(cat "$TARGET")
else
    config='{}'
fi

# Merge each fragment in sorted order.
for f in $(find "$CLAUDE_D" -maxdepth 1 \( -name '*.json' -o -name '*.json.tpl' \) 2>/dev/null | sort); do
    [ -f "$f" ] || continue
    case "$f" in
        *.json.tpl)
            # Template: substitute env vars, then merge
            fragment=$(envsubst < "$f")
            config=$(printf '%s\n%s' "$config" "$fragment" | jq -s '.[0] * .[1]')
            ;;
        *.json)
            config=$(printf '%s' "$config" | jq -s '.[0] * .[1]' - "$f")
            ;;
    esac
done

printf '%s\n' "$config" | jq . > "$TARGET"
