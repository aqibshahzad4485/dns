# 08 Keepalived Configuration

## Purpose
Keepalived provides a highly available Virtual IP (VIP) for clients to query. It runs on the same servers as `dnsdist`.

- **Site A VIP**: `10.10.10.10` (Floats between `DNSDist-A1` and `A2`)
- **Site B VIP**: `10.10.20.10` (Floats between `DNSDist-B1` and `B2`)

## Installation
```bash
sudo apt update
sudo apt install -y keepalived
```

## Health Tracking Script
Keepalived tracks the health of the local `dnsdist` process using a custom bash script (`/usr/local/bin/check-dnsdist.sh`).

The script verifies:
1. `dnsdist` systemd service is active.
2. Port 53 is bound and listening.
3. A local query to `127.0.0.1` successfully resolves `_dns-health.domain.local`.

If this script fails, Keepalived deducts `50` from the server's priority (`weight -50`). The Backup server (priority 100) will then have a higher priority than the Master (200 - 50 = 150 > 100). Wait, if Master is 200 and deducts 50, it becomes 150. If Backup is 100, Master still wins.

**Correction in configs:**
To ensure failover, if Master priority is 200 and Backup is 100, the weight penalty must be at least `-150`.
Alternatively, we will set:
Master Priority: `100`
Backup Priority: `90`
Weight penalty: `-20`
If Master fails, Priority = 80, which is less than 90, triggering failover.

We have adjusted the provided configs to use this math.

## Split-Brain Prevention (VRRP)
VRRP split-brain occurs if the two `dnsdist` nodes in the same site lose network connectivity to each other. Both will assume the VIP, causing IP conflicts.
Since they are in the same subnet (`10.10.10.0/24`), L2 connectivity should be robust. Ensure switches allow multicast `224.0.0.18`.
