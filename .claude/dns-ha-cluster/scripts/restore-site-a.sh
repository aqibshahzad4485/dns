#!/bin/bash
# restore-site-a.sh
# Planned failback: after Site A / A1 has recovered AND has been fenced
# (fence-old-master.sh already run, A1 is a confirmed in-sync SLAVE of
# B1), use this script to hand the "master" role back to A1 during a
# maintenance window.
#
# ORDER OF OPERATIONS MATTERS. We flip B1 -> slave(a1) FIRST, wait for
# it to settle, THEN flip A1 -> master. This means there is a brief
# window (a few seconds) where BOTH nodes are configured as slaves and
# NEITHER is a writable master - that is the safe direction to err in.
# The reverse order (making A1 master first) would create a window
# where BOTH are masters simultaneously, which is the split-brain case.
#
# Usage: ./restore-site-a.sh

set -euo pipefail

A1=10.10.10.11
B1=10.10.20.11
ZONE=domain.local

echo "== Pre-flight: confirm A1 and B1 serials match =============================="
A1_SERIAL=$(ssh "root@${A1}" "knotc zone-status ${ZONE}" | grep -oE 'serial [0-9]+' | head -1 || true)
B1_SERIAL=$(ssh "root@${B1}" "knotc zone-status ${ZONE}" | grep -oE 'serial [0-9]+' | head -1 || true)
echo "A1: ${A1_SERIAL}   B1: ${B1_SERIAL}"
if [ "$A1_SERIAL" != "$B1_SERIAL" ]; then
  echo "ABORT: serials do not match. Run fence-old-master.sh first and let it"
  echo "fully AXFR/IXFR before attempting failback."
  exit 1
fi

read -r -p "Confirm this is a planned maintenance window failback [yes/NO]: " confirm
[ "$confirm" = "yes" ] || { echo "Aborted."; exit 1; }

echo
echo "== Step 1/4: point Knot-A2 / Knot-A3 back at a1 (if they were re-pointed at b1) =="
for slave in 10.10.10.12 10.10.10.13; do
  ssh "root@${slave}" bash -s <<EOF || true
set -e
current=\$(knotc conf-get 'zone[${ZONE}].master' | tr -d '[:space:]')
if [ "\$current" = "b1" ]; then
  knotc conf-begin
  knotc conf-set zone[${ZONE}].master a1
  knotc conf-commit
  echo "Re-pointed \$(hostname) back to a1 (will resync once a1 is master again)"
fi
EOF
done

echo
echo "== Step 2/4: demote B1 back to slave of a1 =================================="
ssh "root@${B1}" bash -s <<EOF
set -e
knotc conf-begin
knotc conf-set zone[${ZONE}].master a1
knotc conf-commit
EOF

echo
echo "== Step 3/4: promote A1 back to master ======================================"
ssh "root@${A1}" bash -s <<EOF
set -e
knotc conf-begin
knotc conf-unset zone[${ZONE}].master
knotc conf-commit
knotc zone-status ${ZONE}
EOF

echo
echo "== Step 4/4: force B1 to refresh from A1, verify convergence ================"
ssh "root@${B1}" "knotc zone-refresh ${ZONE}; sleep 2; knotc zone-status ${ZONE}"

echo
echo "== Final cluster status ====================================================="
A1_SERIAL2=$(ssh "root@${A1}" "knotc zone-status ${ZONE}" | grep -oE 'serial [0-9]+' | head -1 || true)
B1_SERIAL2=$(ssh "root@${B1}" "knotc zone-status ${ZONE}" | grep -oE 'serial [0-9]+' | head -1 || true)
echo "A1: ${A1_SERIAL2}   B1: ${B1_SERIAL2}"
if [ "$A1_SERIAL2" = "$B1_SERIAL2" ]; then
  echo "FAILBACK COMPLETE. A1 is master, B1 is standby master (slave of a1) again."
else
  echo "WARNING: post-failback serials differ - investigate immediately with"
  echo "cluster-status.sh. Do not consider failback complete."
  exit 1
fi
