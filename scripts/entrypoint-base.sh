#!/bin/sh
set -eu

if [ -x /usr/local/bin/wg-up.sh ]; then
    /usr/local/bin/wg-up.sh || true
fi

exec "$@"
