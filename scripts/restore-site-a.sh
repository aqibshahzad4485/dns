#!/bin/bash
# Script to run on Knot-A1 to restore it as the Primary Master
# IMPORTANT: Ensure Knot-B1 has been demoted first!

set -e

echo "Starting restoration of Site A (Knot-A1)..."

# Begin configuration transaction
knotc conf-begin

# Remove the master setting (makes it master again)
knotc conf-unset zone[domain.local].master

# Remove the notify ACL from B
knotc conf-unset zone[domain.local].acl allow_notify_from_b

# Restore our notification to Site B
knotc conf-set zone[domain.local].notify site_b_primary

# Commit changes
knotc conf-commit

# Reload the zone
knotc zone-reload domain.local

echo "Restoration complete. Knot-A1 is now the Primary Master."
knotc zone-status domain.local
