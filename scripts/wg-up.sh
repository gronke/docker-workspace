#!/bin/sh
# Bring up any WireGuard tunnels found under /etc/wireguard.
# Designed for use with a bind-mounted -v /path/to/wg:/etc/wireguard:ro.
# Non-fatal: a misconfigured tunnel must not prevent the container
# from starting. Idempotent: skips interfaces already up so the
# script can be re-run safely.
set -u

case "${WG_AUTOSTART:-1}" in
    0|false|no|off) exit 0 ;;
esac

[ -d /etc/wireguard ] || exit 0
command -v wg-quick >/dev/null 2>&1 || exit 0

for conf in /etc/wireguard/*.conf; do
    [ -e "$conf" ] || continue
    iface=$(basename "$conf" .conf)

    if sudo -n wg show "$iface" >/dev/null 2>&1; then
        printf 'wg: %s already up, skipping\n' "$iface" >&2
        continue
    fi

    printf 'wg: bringing up %s\n' "$iface" >&2
    if ! sudo -n wg-quick up "$conf" >&2; then
        printf 'wg: failed to bring up %s (see message above)\n' "$iface" >&2
    fi
done
