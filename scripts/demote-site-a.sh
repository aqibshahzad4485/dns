#!/bin/bash
# Script to run on Knot-A1 to safely demote it if Site B is the active master
# This prevents split-brain if Site A is isolated but Knot-A1 is still running

set -e

echo "Starting demotion of Site A (Knot-A1)..."

# Begin configuration transaction
knotc conf-begin

# Set Site B as our master
knotc conf-set zone[domain.local].master site_b_primary

# Allow Site B to notify us
knotc conf-set zone[domain.local].acl allow_notify_from_b

# Remove our notification to Site B
# (Optional, but cleaner)
knotc conf-unset zone[domain.local].notify site_b_primary

# Commit changes
knotc conf-commit

# Reload the zone and force a retransfer to sync up with B1
knotc zone-reload domain.local
knotc zone-retransfer domain.local

echo "Demotion complete. Knot-A1 is now a Slave to Knot-B1."
knotc zone-status domain.local
