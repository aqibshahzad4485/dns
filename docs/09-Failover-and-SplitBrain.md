# 09 Failover and Split-Brain

## Manual Failover Process

If Site A goes down entirely (e.g., power loss or network cut), `Knot-B1` will no longer receive updates from `Knot-A1`.
By default, clients in Site A and Site B will still resolve DNS because `dnsdist` at Site B will answer from its cache, and if needed, query the local Site B slaves.

However, to **update** DNS records during a Site A outage, you must promote `Knot-B1` to Primary Master.

### Step 1: Promote Site B (Knot-B1)
Run the promotion script on `Knot-B1`:
```bash
sudo /opt/scripts/promote-site-b.sh
```
This script removes the `master` designation from `B1`, allowing it to serve as a standalone Primary Master and accept dynamic updates (if configured) or manual zone file edits.

### Step 2: Demote Site A (If Reachable)
If Site A is partially reachable, you must ensure `Knot-A1` is demoted so it does not accept conflicting updates (Split-Brain).
Run the demotion script on `Knot-A1`:
```bash
sudo /opt/scripts/demote-site-a.sh
```

## Restoring Site A (Failback)

Once Site A recovers, you must safely sync the latest changes from B back to A before making A the primary again.

### Step 1: Sync B to A
Run the restore script on `Knot-A1`:
```bash
sudo /opt/scripts/restore-site-a.sh
```
This script temporarily configures `Knot-A1` as a slave to `Knot-B1`, forces a zone transfer, and waits for synchronization.

### Step 2: Demote Site B
Run the demotion script on `Knot-B1`:
```bash
sudo /opt/scripts/demote-site-b.sh
```
This script re-adds `Knot-A1` as the master for `Knot-B1`.

### Step 3: Promote Site A
Finally, restore `Knot-A1` to its original Primary Master state:
```bash
sudo /opt/scripts/promote-site-a.sh
```

## Split-Brain Prevention
Split-brain occurs if BOTH `Knot-A1` and `Knot-B1` believe they are the Primary Master and both accept updates.
Because we use manual failover scripts, this is entirely prevented as long as operators follow the procedure above. Future automation hooks can leverage these exact scripts in combination with a distributed lock or consensus (e.g., Consul or etcd) to automate this safely.
