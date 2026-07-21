#!/bin/bash
# /usr/local/bin/check-dnsdist.sh
# Used by keepalived vrrp_script on all 4 dnsdist nodes.
# Exit 0 = healthy (keep/gain MASTER eligibility)
# Exit 1 = unhealthy (keepalived applies track_script weight penalty)

# 1) dnsdist process must be running
systemctl is-active --quiet dnsdist || exit 1

# 2) port 53 must be listening
ss -lnu | grep -q ":53 " || exit 1

# 3) dnsdist must actually answer a query locally (proves the Lua config
#    loaded correctly and at least the packet-handling path is alive)
dig @127.0.0.1 _dns-health.domain.local A +time=1 +tries=1 +short >/dev/null 2>&1 || exit 1

exit 0
