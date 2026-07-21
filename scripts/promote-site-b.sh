#!/bin/bash
# Script to run on Knot-B1 to promote it to Primary Master if Site A is down

set -e

echo "Starting promotion of Site B (Knot-B1)..."

# Begin configuration transaction
knotc conf-begin

# Unset the master for the zone (makes it a master)
knotc conf-unset zone[domain.local].master

# Remove the ACL that allows Site A to notify us (since we are now master)
knotc conf-unset zone[domain.local].acl allow_notify_from_a

# Commit changes
knotc conf-commit

# Reload the zone
knotc zone-reload domain.local

echo "Promotion complete. Knot-B1 is now the Primary Master."
knotc zone-status domain.local
