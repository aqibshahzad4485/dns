# 09 Failover and Split-Brain

This document outlines the architecture, manual procedures, and conceptual differences of managing a failover and failback between Site A and Site B.

## Understanding the Process

In a high-availability active-passive setup, only one server (the Primary Master) should actively accept and serve dynamic DNS updates or zone file modifications at any time. The other site serves as a Standby Master (Slave), continuously replicating the data. 

If Site A goes down entirely (e.g., power loss or network cut), `Knot-B1` will no longer receive updates from `Knot-A1`.
By default, clients in Site A and Site B will still resolve DNS because `dnsdist` at Site B will answer from its cache, and if needed, query the local Site B slaves.

However, to **update** DNS records during a Site A outage, you must promote `Knot-B1` to Primary Master.

### Difference Between Commands (`knotc`), Scripts, and Config Files

There are two primary ways to manage the role of a Knot DNS server:

1. **Editing `knot.conf` Directly**:
   - **How it works**: You manually open `/etc/knot/knot.conf` and add/remove the `master: ...` directive inside your `zone:` block. 
   - **Pros**: Persistent across service restarts and server reboots. It serves as your permanent infrastructure-as-code state.
   - **Cons**: Requires `systemctl reload knot` to take effect, which is slightly slower than a dynamic state change.
   - **How to update**: 
     - To make a server a **Primary Master**, remove or comment out the `master: ...` line in its zone configuration.
     - To make a server a **Standby Master (Slave)**, add `master: site_a_primary` (or equivalent) to its zone configuration.

2. **Using `knotc` Commands or Scripts**:
   - **How it works**: You use `knotc conf-set` and `knotc conf-unset` commands to dynamically change the server's running state in real-time. (This is what the `scripts/` directory does).
   - **Pros**: Instantaneous and allows for programmatic automation without parsing text files.
   - **Cons**: Depending on your `confdb` settings, dynamic changes made with `knotc` may **not** be permanent. If Knot DNS is restarted (`systemctl restart knot`), it will reload its state from `knot.conf`, destroying any temporary `knotc` promotions or demotions.
   - **How to avoid state loss**: To make state changes persistent, you must replicate the role change in your `knot.conf` file manually after running a failover script, OR configure Knot DNS to export its `confdb` changes to the configuration file automatically.

---

## Manual Failover Process (Site A -> Site B)

If Site A goes offline and you need to make changes to DNS records, you must promote Site B.

### Step 1: Promote Site B (Knot-B1)
Run the promotion script on `Knot-B1`:
```bash
sudo /opt/scripts/promote-site-b.sh
```
This script temporarily unsets the `master` designation from `B1`, allowing it to serve as a standalone Primary Master and accept dynamic updates or manual zone file edits.

### Step 2: Demote Site A (If Reachable)
If Site A is partially reachable, you must ensure `Knot-A1` is demoted so it does not accept conflicting updates. 
```bash
sudo /opt/scripts/demote-site-a.sh
```

---

## Restoring Site A (Failback: Site B -> Site A)

Once Site A recovers, you must safely sync the latest changes from B back to A before making A the primary again. If you just turn Site A on as Primary, you will cause a **Split-Brain** because it will have outdated data while Site B has new data.

### Step 1: Sync B to A (Demote Site A to Standby)
First, force `Knot-A1` to act as a backup to `Knot-B1` so it can download everything it missed. Run this on `Knot-A1`:
```bash
sudo /opt/scripts/demote-site-a.sh
```
This temporarily configures `Knot-A1` as a slave to `Knot-B1`, forces a zone transfer, and waits for synchronization. It will then pass those updates to its own local slaves.

### Step 2: Demote Site B back to Standby
Once Site A is fully up-to-date, stop Site B from acting as the Primary Master. Run this on `Knot-B1`:
```bash
sudo /opt/scripts/demote-site-b.sh
```
This script re-adds `Knot-A1` as the master for `Knot-B1`.

### Step 3: Promote Site A back to Primary
Finally, restore `Knot-A1` to its original Primary Master state. Run this on `Knot-A1`:
```bash
sudo /opt/scripts/restore-site-a.sh
```
This script unsets the slave configuration, returning `Knot-A1` to active duty.

---

## Split-Brain Prevention
Split-brain occurs if BOTH `Knot-A1` and `Knot-B1` believe they are the Primary Master and both accept updates.
Because we use manual failover scripts and strictly adhere to the sync-first methodology (Failback Step 1), this is prevented.

## Master Interactive Script
For easier management, you can use the interactive master script:
```bash
sudo /opt/scripts/master-failover.sh
```
This script will list active zones, prompt you to select an action (Promote/Demote A or B), execute the necessary `knotc` commands, and automatically verify if the role state was updated successfully, warning you if manual checks are needed.
