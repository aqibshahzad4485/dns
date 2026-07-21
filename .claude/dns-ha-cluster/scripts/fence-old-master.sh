#!/bin/bash
# fence-old-master.sh
# Run this the MOMENT Knot-A1 comes back online after an outage during
# which Knot-B1 was promoted (promote-site-b.sh). This is the single
# most important anti-split-brain step in the whole runbook: it forces
# A1 to immediately become a SLAVE of the NEW master (b1) before anyone
# can write to it or before it re-announces itself via any stale config.
#
# It does NOT try to figure out who is "right" - B1 is authoritative
# for the duration of the incident, full stop. A1 always converges to B1.
#
# Usage: ./fence-old-master.sh

set -euo pipefail

A1=10.10.10.11
B1=10.10.20.11
ZONE=domain.local

echo "== Step 1/3: confirm A1 is reachable ==="
ssh -o ConnectTimeout=3 "root@${A1}" true

echo "== Step 2/3: force A1 to become a SLAVE of B1 (discard any local writes) ==="
ssh "root@${A1}" bash -s <<EOF
set -e
knotc conf-begin
knotc conf-set zone[${ZONE}].master b1
knotc conf-commit
knotc zone-refresh ${ZONE}
sleep 2
knotc zone-status ${ZONE}
EOF

echo "== Step 3/3: verify serial now matches B1 ==="
A1_SERIAL=$(ssh "root@${A1}" "knotc zone-status ${ZONE}" | grep -oE 'serial [0-9]+' | head -1 || true)
B1_SERIAL=$(ssh "root@${B1}" "knotc zone-status ${ZONE}" | grep -oE 'serial [0-9]+' | head -1 || true)
echo "A1: ${A1_SERIAL}   B1: ${B1_SERIAL}"

if [ "$A1_SERIAL" = "$B1_SERIAL" ]; then
  echo "OK: A1 is fenced and in sync with B1. Safe to leave running as a slave"
  echo "indefinitely, or proceed to restore-site-a.sh when ready to fail back."
else
  echo "WARNING: serials differ or could not be parsed - check manually with"
  echo "cluster-status.sh before proceeding. Do NOT unset A1's master until"
  echo "the serials match."
  exit 1
fi
