#!/bin/bash
# Health check script used by Keepalived to verify dnsdist is healthy

# 1. Verify dnsdist process is active
systemctl is-active --quiet dnsdist || exit 1

# 2. Verify port 53 is listening
ss -lnup | grep -q ":53 " || exit 1

# 3. Verify local DNS answers
dig @127.0.0.1 _dns-health.domain.local A +time=1 +tries=1 >/dev/null 2>&1 || exit 1

exit 0
