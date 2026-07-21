#!/bin/bash
# cluster-status.sh
# Run from a management workstation/jump host that has SSH key access
# (as root, or a sudoer that can run knotc) to all 6 Knot nodes.
# Prints: node, configured master, zone serial, zone status.
#
# ALWAYS run this before any promotion/failback decision.

set -euo pipefail

declare -A NODES=(
  [Knot-A1]=10.10.10.11
  [Knot-A2]=10.10.10.12
  [Knot-A3]=10.10.10.13
  [Knot-B1]=10.10.20.11
  [Knot-B2]=10.10.20.12
  [Knot-B3]=10.10.20.13
)

printf "%-10s %-14s %-14s %-14s %-30s\n" "NODE" "IP" "REACHABLE" "MASTER-CFG" "ZONE-STATUS (domain.local)"
printf "%-10s %-14s %-14s %-14s %-30s\n" "----" "--" "---------" "----------" "--------------------------"

for name in "${!NODES[@]}"; do
  ip="${NODES[$name]}"
  if ssh -o ConnectTimeout=3 -o BatchMode=yes "root@${ip}" true 2>/dev/null; then
    master=$(ssh "root@${ip}" "knotc conf-get 'zone[domain.local].master'" 2>/dev/null | tr -d '\n' || echo "(none/self)")
    [ -z "$master" ] && master="(none = MASTER)"
    status=$(ssh "root@${ip}" "knotc zone-status domain.local" 2>/dev/null | tr '\n' ' ' || echo "ERROR")
    printf "%-10s %-14s %-14s %-14s %-30s\n" "$name" "$ip" "UP" "$master" "$status"
  else
    printf "%-10s %-14s %-14s %-14s %-30s\n" "$name" "$ip" "DOWN" "?" "unreachable"
  fi
done
