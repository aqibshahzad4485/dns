#!/bin/bash
# /usr/local/bin/vrrp-notify.sh
# Called by keepalived on every state transition. Logs to syslog so VIP
# flaps are visible via `journalctl -u keepalived` / your log shipper.
STATE="$1"
logger -t keepalived-vrrp "VRRP transition on $(hostname): now $STATE"
