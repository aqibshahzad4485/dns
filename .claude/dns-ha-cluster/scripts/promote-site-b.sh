#!/bin/bash
# promote-site-b.sh
# Run from a management host. Promotes Knot-B1 (10.10.20.11) from
# STANDBY MASTER (slave of A1) to ACTIVE MASTER, for use when Site A /
# Knot-A1 is confirmed down or unreachable.
#
# SAFETY DESIGN:
#  - Refuses to run if A1 is still reachable, unless --force is given.
#    (Promoting while the old master is still alive is exactly how you
#    get two writable masters = split-brain.)
#  - Only ever unsets B1's "master:" property. Never touches ACLs, so
#    no risk of accidentally opening transfer/notify to the wrong peer.
#  - Prints the zone-status before AND after so you have evidence of
#    the serial at time of promotion for the post-incident report.
#
# Usage: ./promote-site-b.sh [--force]

set -euo pipefail

A1=10.10.10.11
B1=10.10.20.11
ZONE=domain.local
FORCE="${1:-}"

echo "== Step 1/4: checking reachability of A1 (${A1}) =========================="
if ssh -o ConnectTimeout=3 -o BatchMode=yes "root@${A1}" true 2>/dev/null; then
  if [ "$FORCE" != "--force" ]; then
    echo "ABORT: Knot-A1 is still reachable via SSH. Promoting B1 now would"
    echo "create TWO writable masters (split-brain). If you are certain A1 must"
    echo "be forced out of service (e.g. it is corrupted but network-reachable),"
    echo "fence it first (see fence-old-master.sh) or re-run with --force."
    exit 1
  else
    echo "WARNING: A1 is reachable but --force was given. Proceeding anyway."
    echo "You MUST fence A1 (stop knot / block port 53) manually right now in"
    echo "another window before continuing, or you WILL get split-brain."
    read -r -p "Type 'fenced' once A1 is fenced: " confirm
    [ "$confirm" = "fenced" ] || { echo "Aborted."; exit 1; }
  fi
else
  echo "A1 is unreachable - proceeding with promotion."
fi

echo
echo "== Step 2/4: pre-promotion zone status on B1 ==============================="
ssh "root@${B1}" "knotc zone-status ${ZONE}"

echo
echo "== Step 3/4: promoting B1 to MASTER =========================================="
ssh "root@${B1}" bash -s <<EOF
set -e
knotc conf-begin
knotc conf-unset zone[${ZONE}].master
knotc conf-commit
knotc zone-status ${ZONE}
EOF

echo
echo "== Step 4/4: post-promotion status =========================================="
ssh "root@${B1}" "knotc zone-status ${ZONE}"

cat <<'EON'

PROMOTION COMPLETE.
Knot-B1 is now the writable master for domain.local.
Knot-B2/B3 keep working unchanged (they already point at b1).
dnsdist requires NO changes (backends are B2/B3 and A2/A3, unaffected).

NEXT STEPS (choose based on expected outage duration):
  * Short outage expected (<1h): do nothing further, just wait, then run
    restore-site-a.sh once A1 is back.
  * Extended outage: consider re-pointing Knot-A2 / Knot-A3 directly at
    b1 across the WAN so Site A clients still get fresh answers:
        ssh root@10.10.10.12 "knotc conf-begin; knotc conf-set zone[domain.local].master b1; knotc conf-commit; knotc zone-refresh domain.local"
        ssh root@10.10.10.13 "knotc conf-begin; knotc conf-set zone[domain.local].master b1; knotc conf-commit; knotc zone-refresh domain.local"
    (Revert these to 'a1' again as part of restore-site-a.sh.)
EON
