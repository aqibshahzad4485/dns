#!/bin/bash
# Script to run on any Slave node (A2, A3, B2, B3) to switch its Master source

set -e

echo "Fetching active zones..."
ZONES=$(knotc conf-read zone.domain 2>/dev/null | grep -Eo '^zone\[[^]]+\]' | sed 's/zone\[\(.*\)\]/\1/')
if [ -z "$ZONES" ]; then
    echo "Warning: Could not fetch zones automatically."
    echo "Using default zone: domain.local"
    ZONES="domain.local"
fi

echo "Active zones found:"
echo "$ZONES"
echo ""
read -p "Enter the zone to manage (or press Enter for 'domain.local'): " SELECTED_ZONE
if [ -z "$SELECTED_ZONE" ]; then
    SELECTED_ZONE="domain.local"
fi

echo "========================================="
echo " Slave Master Selection Menu"
echo "========================================="
echo "Which site should this slave sync from?"
echo "1) Site A (Knot-A1) - site_a_primary"
echo "2) Site B (Knot-B1) - site_b_primary"
echo "3) Exit"
echo "========================================="
read -p "Select the new master [1-3]: " ACTION

check_success() {
    local ZONE=$1
    echo "Verifying state change..."
    sleep 2
    STATUS=$(knotc zone-status "$ZONE" 2>/dev/null || echo "Unable to retrieve status")
    
    if echo "$STATUS" | grep -qi "role: slave"; then
        echo "SUCCESS: Zone $ZONE successfully configured as slave and reloaded."
    else
        echo "WARNING: State check failed or timed out. Please manually verify."
        echo "Current status output: $STATUS"
    fi
}

case $ACTION in
    1)
        TARGET_MASTER="site_a_primary"
        ;;
    2)
        TARGET_MASTER="site_b_primary"
        ;;
    3)
        echo "Exiting."
        exit 0
        ;;
    *)
        echo "Invalid selection. Exiting."
        exit 1
        ;;
esac

echo "Switching master for zone $SELECTED_ZONE to $TARGET_MASTER..."
knotc conf-begin
knotc conf-set zone["$SELECTED_ZONE"].master "$TARGET_MASTER"
if knotc conf-commit; then
    knotc zone-reload "$SELECTED_ZONE"
    knotc zone-retransfer "$SELECTED_ZONE" || true
    check_success "$SELECTED_ZONE"
    echo "NOTE: To make this change persistent across service restarts, edit /etc/knot/knot.conf and update the 'master:' field in the zone block."
else
    echo "ERROR: Failed to commit configuration."
    knotc conf-abort
fi
