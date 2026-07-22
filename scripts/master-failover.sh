#!/bin/bash
# Master interactive script for managing Knot DNS Failover and Failback

set -e

echo "Fetching active zones..."
# This attempts to list zones. If knotc is not running, we'll gracefully handle it.
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
echo " Knot DNS Failover Management Menu"
echo "========================================="
echo "1) Demote A1 (Make A1 a Slave of B1 to fetch updates)"
echo "2) Restore/Promote A1 (Make A1 the Primary Master)"
echo "3) Demote B1 (Make B1 a Slave of A1)"
echo "4) Promote B1 (Make B1 the Primary Master)"
echo "5) Exit"
echo "========================================="
read -p "Select an action [1-5]: " ACTION

check_success() {
    # Check zone status to verify role
    local EXPECTED_ROLE=$1
    local ZONE=$2
    echo "Verifying state change..."
    sleep 2
    STATUS=$(knotc zone-status "$ZONE" 2>/dev/null || echo "Unable to retrieve status")
    
    if echo "$STATUS" | grep -qi "role: $EXPECTED_ROLE"; then
        echo "SUCCESS: Zone $ZONE successfully updated to $EXPECTED_ROLE."
    else
        echo "WARNING: State check failed or timed out. Please manually verify."
        echo "Current status output: $STATUS"
    fi
}

case $ACTION in
    1)
        echo "Demoting A1 for zone $SELECTED_ZONE..."
        knotc conf-begin
        knotc conf-set zone["$SELECTED_ZONE"].master site_b_primary
        knotc conf-set zone["$SELECTED_ZONE"].acl allow_notify_from_b
        if knotc conf-commit; then
            knotc zone-reload "$SELECTED_ZONE"
            knotc zone-retransfer "$SELECTED_ZONE" || true
            check_success "slave" "$SELECTED_ZONE"
        else
            echo "ERROR: Failed to commit configuration."
            knotc conf-abort
        fi
        ;;
    2)
        echo "Restoring A1 to Primary Master for zone $SELECTED_ZONE..."
        knotc conf-begin
        knotc conf-unset zone["$SELECTED_ZONE"].master
        knotc conf-unset zone["$SELECTED_ZONE"].acl allow_notify_from_b
        knotc conf-set zone["$SELECTED_ZONE"].notify site_b_primary || true
        if knotc conf-commit; then
            knotc zone-reload "$SELECTED_ZONE"
            check_success "master" "$SELECTED_ZONE"
        else
            echo "ERROR: Failed to commit configuration."
            knotc conf-abort
        fi
        ;;
    3)
        echo "Demoting B1 for zone $SELECTED_ZONE..."
        knotc conf-begin
        knotc conf-set zone["$SELECTED_ZONE"].master site_a_primary
        knotc conf-set zone["$SELECTED_ZONE"].acl allow_notify_from_a
        if knotc conf-commit; then
            knotc zone-reload "$SELECTED_ZONE"
            check_success "slave" "$SELECTED_ZONE"
        else
            echo "ERROR: Failed to commit configuration."
            knotc conf-abort
        fi
        ;;
    4)
        echo "Promoting B1 to Primary Master for zone $SELECTED_ZONE..."
        knotc conf-begin
        knotc conf-unset zone["$SELECTED_ZONE"].master
        knotc conf-unset zone["$SELECTED_ZONE"].acl allow_notify_from_a
        if knotc conf-commit; then
            knotc zone-reload "$SELECTED_ZONE"
            check_success "master" "$SELECTED_ZONE"
        else
            echo "ERROR: Failed to commit configuration."
            knotc conf-abort
        fi
        ;;
    5)
        echo "Exiting."
        exit 0
        ;;
    *)
        echo "Invalid selection. Exiting."
        exit 1
        ;;
esac
