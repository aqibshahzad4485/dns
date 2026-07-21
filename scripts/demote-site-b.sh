#!/bin/bash
# Script to run on Knot-B1 to safely demote it back to Standby Master
# This is used after Site A has recovered and synced from B

set -e

echo "Starting demotion of Site B (Knot-B1)..."

# Begin configuration transaction
knotc conf-begin

# Set Site A as our master
knotc conf-set zone[domain.local].master site_a_primary

# Allow Site A to notify us
knotc conf-set zone[domain.local].acl allow_notify_from_a

# Commit changes
knotc conf-commit

# Reload the zone
knotc zone-reload domain.local

echo "Demotion complete. Knot-B1 is now a Standby Master (Slave to Knot-A1)."
knotc zone-status domain.local
