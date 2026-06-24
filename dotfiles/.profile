# ~/.profile

# Imply GIT_AUTHOR_*/GIT_COMMITTER_* + git config from a single GIT_USER_* pair.
# Override either piece by setting the 4-tuple directly.
if [ -n "${GIT_USER_NAME:-}" ]; then
    export GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-$GIT_USER_NAME}"
    export GIT_COMMITTER_NAME="${GIT_COMMITTER_NAME:-$GIT_USER_NAME}"
    git config --global user.name "$GIT_USER_NAME" 2>/dev/null || true
fi
if [ -n "${GIT_USER_EMAIL:-}" ]; then
    export GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-$GIT_USER_EMAIL}"
    export GIT_COMMITTER_EMAIL="${GIT_COMMITTER_EMAIL:-$GIT_USER_EMAIL}"
    git config --global user.email "$GIT_USER_EMAIL" 2>/dev/null || true
fi

export DISABLE_TELEMETRY=1
export DO_NOT_TRACK=1
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
export DISABLE_ERROR_REPORTING=1
export DISABLE_FEEDBACK_COMMAND=1
export CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY=1

#export CLAUDE_CODE_ENABLE_FEEDBACK_SURVEY_FOR_OTEL=1