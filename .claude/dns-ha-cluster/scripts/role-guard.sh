#!/bin/bash
# /usr/local/bin/role-guard.sh
# Split-brain safety net: this cluster NEVER grants "action: update" in any
# ACL, so DNS dynamic updates cannot create split-brain. The only remaining
# risk is a HUMAN manually editing the zone file on two nodes at once.
# This script is that guard rail: it refuses to let you edit the zone file
# unless knotc currently reports this node as the master (no "master:"
# property set for the zone).
#
# Usage:  role-guard.sh edit      # opens $EDITOR on the zone file, only if MASTER
#         role-guard.sh check     # just prints role and exits 0/1

set -euo pipefail

ZONE="domain.local"
ZONEFILE="/var/lib/knot/${ZONE}.zone"

MASTER_CFG=$(knotc conf-get "zone[${ZONE}].master" 2>/dev/null | tr -d '[:space:]' || true)

if [ -n "$MASTER_CFG" ]; then
  echo "REFUSED: this node is a SLAVE of '${MASTER_CFG}'. Do not edit ${ZONEFILE} here."
  echo "Edit the zone on the current MASTER instead. Run cluster-status.sh to confirm."
  exit 1
fi

echo "OK: this node has no 'master:' set -> it IS the current master for ${ZONE}."

case "${1:-check}" in
  check)
    exit 0
    ;;
  edit)
    ${EDITOR:-nano} "$ZONEFILE"
    echo "Validating zone..."
    knotc zone-check "$ZONE"
    echo "Reloading..."
    knotc zone-reload "$ZONE"
    knotc zone-status "$ZONE"
    ;;
  *)
    echo "Usage: $0 [check|edit]"
    exit 2
    ;;
esac
