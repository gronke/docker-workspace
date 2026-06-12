#!/bin/sh
# claude.d hook (shellenv phase): define the interactive `claude` launch alias.
#
# model + effort live in ~/.claude/settings.json (assembled from the
# claude.d settings.json target), so CLAUDE_ARGS no longer pins them — it
# carries only runtime/session flags the operator wants appended to every
# interactive launch. The `eval` re-parses CLAUDE_ARGS through the shell
# tokenizer so quoted values survive intact.
[ "${CLAUDE_CONFIG_PHASE:-}" = apply ] && return 0 2>/dev/null || true

: "${CLAUDE_ARGS:=}"
export CLAUDE_ARGS
alias claude='eval command claude $CLAUDE_ARGS'
