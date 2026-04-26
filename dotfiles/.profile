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
