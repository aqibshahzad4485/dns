# Multi-Site Knot DNS + dnsdist + keepalived HA Cluster

Two-site, fully local (no internet), authoritative DNS cluster for
`domain.local` with automatic local load-balancing/failover (dnsdist +
keepalived) and a controlled, split-brain-safe manual/scripted procedure
for master failover between sites (Knot AXFR/IXFR + TSIG).

---

## 1. Inventory / IP Plan

| Role                     | Hostname     | IP            | Site | Notes                        |
|--------------------------|--------------|---------------|------|-------------------------------|
| Primary Master           | Knot-A1      | 10.10.10.11   | A    | Writable master (normal ops) |
| Slave 1                  | Knot-A2      | 10.10.10.12   | A    | dnsdist-A backend             |
| Slave 2                  | Knot-A3      | 10.10.10.13   | A    | dnsdist-A backend             |
| dnsdist node 1           | DNSDist-A1   | 10.10.10.16   | A    | keepalived MASTER (default)   |
| dnsdist node 2           | DNSDist-A2   | 10.10.10.17   | A    | keepalived BACKUP             |
| **VIP (Site A clients)** | DNSDist-AVIP | **10.10.10.10** | A | client-facing resolver #1    |
| Standby Master           | Knot-B1      | 10.10.20.11   | B    | Slave of A1 (normal ops)      |
| Slave 1                  | Knot-B2      | 10.10.20.12   | B    | dnsdist-B backend             |
| Slave 2                  | Knot-B3      | 10.10.20.13   | B    | dnsdist-B backend             |
| dnsdist node 1           | DNSDist-B1   | 10.10.20.16   | B    | keepalived MASTER (default)   |
| dnsdist node 2           | DNSDist-B2   | 10.10.20.17   | B    | keepalived BACKUP             |
| **VIP (Site B clients)** | DNSDist-BVIP | **10.10.20.10** | B | client-facing resolver #1    |

Networks: Site A `10.10.10.0/24`, Site B `10.10.20.0/24`. Both subnets are
routed and mutually reachable (no NAT, no internet) — e.g. via a core
router/L3 switch or a WAN link between sites. All AXFR/IXFR, NOTIFY, and
health-check traffic between sites crosses that link on port 53 (TCP+UDP).

> **Fix applied vs. your original configs:** Site B's original
> `knot.conf` files used `10.10.10.x` addresses (copy-paste from Site A)
> and Site B's original keepalived VIP was `10.10.10.20/24` — inside
> Site A's subnet, which would never work and risked address collision.
> Everything below uses the corrected `10.10.20.0/24` addressing.

### Client resolver configuration

| Clients at | Primary DNS (`nameserver` #1) | Secondary DNS (`nameserver` #2) |
|---|---|---|
| Site A | `10.10.10.10` (DNSDist-AVIP) | `10.10.20.10` (DNSDist-BVIP) |
| Site B | `10.10.20.10` (DNSDist-BVIP) | `10.10.10.10` (DNSDist-AVIP) |

Push this via DHCP option 6, or static `/etc/resolv.conf` / NIC settings.

---

## 2. Architecture Diagram

```
                              ┌───────────────────────────────────────────┐
                              │        Routed backbone (no internet)      │
                              │        10.10.10.0/24  <──────>  10.10.20.0/24 │
                              └───────────────────────────────────────────┘
        SITE A  (10.10.10.0/24)                        SITE B  (10.10.20.0/24)
 ┌───────────────────────────────────┐        ┌───────────────────────────────────┐
 │ Clients -> .10 (VIP-A) -> .20(VIP-B)│        │ Clients -> .20 (VIP-B) -> .10(VIP-A)│
 │                                     │        │                                     │
 │   ┌────────────┐   VRRP  ┌────────┐│        │   ┌────────────┐   VRRP  ┌────────┐│
 │   │DNSDist-A1  │<------->│DNSDist-A2││        │   │DNSDist-B1  │<------->│DNSDist-B2││
 │   │10.10.10.16 │ MASTER  │.17 BACKUP││        │   │10.10.20.16 │ MASTER  │.17 BACKUP││
 │   └─────┬──────┘         └───┬────┘│        │   └─────┬──────┘         └───┬────┘│
 │         │   VIP 10.10.10.10   │     │        │         │   VIP 10.10.20.10   │     │
 │         └──────────┬──────────┘     │        │         └──────────┬──────────┘     │
 │             pool "local" (preferred)│        │             pool "local" (preferred)│
 │           ┌─────────┴─────────┐     │        │           ┌─────────┴─────────┐     │
 │      ┌────▼────┐        ┌─────▼───┐ │        │      ┌────▼────┐        ┌─────▼───┐ │
 │      │Knot-A2  │        │Knot-A3  │ │        │      │Knot-B2  │        │Knot-B3  │ │
 │      │.12 slave│        │.13 slave│ │        │      │.12 slave│        │.13 slave│ │
 │      └────▲────┘        └────▲────┘ │        │      └────▲────┘        └────▲────┘ │
 │           │   AXFR/IXFR+NOTIFY│      │        │           │   AXFR/IXFR+NOTIFY│      │
 │           └─────────┬─────────┘      │        │           └─────────┬─────────┘      │
 │                 ┌───▼────┐           │        │                 ┌───▼────┐           │
 │                 │Knot-A1 │◄──────────┼─AXFR/IXFR + NOTIFY───────►│Knot-B1 │           │
 │                 │.11     │  (TSIG: xfr_intersite, over the backbone) │.11 STANDBY   │
 │                 │PRIMARY │           │        │                 │MASTER (slave  │
 │                 │MASTER  │           │        │                 │  of A1)       │
 │                 └────────┘           │        │                 └────────┘           │
 │  dnsdist "remote" pool (fallback) ───┼───────►│Knot-B2/B3 (cross-site fallback only)  │
 │◄──────── dnsdist "remote" pool (fallback) ────┼── Knot-A2/A3 (cross-site fallback)    │
 └───────────────────────────────────┘        └───────────────────────────────────┘
```

**Query flow (normal operation):**
1. Site A client asks `10.10.10.10` (VIP) → whichever dnsdist currently
   holds the VIP (A1 by default) → `pool "local"` (Knot-A2/A3, load
   balanced with `leastOutstanding`).
2. If both Knot-A2 and Knot-A3 fail health checks → `PoolAvailableRule("local")`
   goes false → dnsdist automatically routes to `pool "remote"`
   (Knot-B2/B3) across the backbone — no keepalived event needed.
3. If **both dnsdist-A1 and dnsdist-A2** are down → the VIP itself is
   gone → client's stub resolver times out on `.10` and retries against
   its **secondary** nameserver, `10.10.20.10` (Site B VIP), which serves
   the same zone (data is present at both sites).

**Replication flow (normal operation):**
`Knot-A1` (writable) → AXFR/IXFR+NOTIFY → `Knot-A2`, `Knot-A3` (local
slaves) **and** → `Knot-B1` (inter-site, standby master) → AXFR/IXFR+NOTIFY
→ `Knot-B2`, `Knot-B3`.

This is a **single-writer, pull-based replication tree** — there is
always exactly one node without a `master:` property (the active
master), and every other node transitively pulls from it. No node is
ever configured to accept `action: update` (dynamic DNS updates), so
there is no protocol-level path for two nodes to be written to
concurrently — see §8 Split-Brain Prevention.

---

## 3. TSIG Keys

Three keys, one per relationship, generated with `keymgr` (example
secrets already generated for you in `knot/keys.conf` — **regenerate
before production use**):

```bash
keymgr -t xfr_site_a hmac-sha256       # A1 <-> A2, A1 <-> A3
keymgr -t xfr_site_b hmac-sha256       # B1 <-> B2, B1 <-> B3
keymgr -t xfr_intersite hmac-sha256    # A1 <-> B1
```

Deploy the resulting `knot/keys.conf` **identically** to all 6 Knot
nodes:

```bash
scp knot/keys.conf root@<node>:/etc/knot/keys.conf
ssh root@<node> "chown root:knot /etc/knot/keys.conf && chmod 640 /etc/knot/keys.conf"
```

Every `knot-*.conf` in this repo does `include: /etc/knot/keys.conf` and
references keys by `id` in `remote:`/`acl:` blocks — never inline.

---

## 4. Installation

Run on **all 6 Knot nodes** (Debian/Ubuntu shown; adjust for your distro):

```bash
apt update
apt install -y knot knot-dnsutils
systemctl enable knot
mkdir -p /var/lib/knot /run/knot
chown -R knot:knot /var/lib/knot /run/knot
```

Copy the matching `knot-*.conf` from this repo to `/etc/knot/knot.conf`
on each node (see §1 table for the mapping), plus `keys.conf` (§3).
**Only Knot-A1** also gets the initial zone file:

```bash
# On Knot-A1 only:
cp knot/domain.local.zone /var/lib/knot/domain.local.zone
chown knot:knot /var/lib/knot/domain.local.zone
knotc conf-check
knotc zone-check domain.local
systemctl restart knot
knotc zone-status domain.local
```

```bash
# On Knot-A2, A3, B1, B2, B3 (all slaves initially):
knotc conf-check
systemctl restart knot
knotc zone-refresh domain.local     # trigger initial AXFR
knotc zone-status domain.local      # confirm serial matches A1
```

Run on **all 4 dnsdist nodes**:

```bash
apt update
apt install -y dnsdist
cp dnsdist/dnsdist-<NODE>.conf /etc/dnsdist/dnsdist.conf
# edit the placeholder password/apiKey before starting!
systemctl enable --now dnsdist
dnsdist -c /etc/dnsdist/dnsdist.conf --check-config   # syntax check
systemctl restart dnsdist
```

Run on the **same 4 dnsdist nodes** for keepalived:

```bash
apt install -y keepalived
cp scripts/check-dnsdist.sh /usr/local/bin/check-dnsdist.sh
cp scripts/vrrp-notify.sh   /usr/local/bin/vrrp-notify.sh
chmod +x /usr/local/bin/check-dnsdist.sh /usr/local/bin/vrrp-notify.sh
cp keepalived/keepalived-<NODE>.conf /etc/keepalived/keepalived.conf
# edit auth_pass placeholders, confirm interface name (ip a) matches "eth0"
systemctl enable --now keepalived
ip a show eth0 | grep 10.10.1   # confirm VIP appears on the MASTER node
```

Firewall note (all nodes): allow TCP/UDP 53 between the two subnets, UDP
112/VRRP (or unicast VRRP, see §9) between the two dnsdist nodes at each
site only, and TCP 8083 restricted to loopback/mgmt.

---

## 5. Knot Configuration Map

| File | Node | Role | `master:` set? |
|---|---|---|---|
| `knot/knot-A1.conf` | Knot-A1 (10.10.10.11) | Primary Master | No (is master) |
| `knot/knot-A2.conf` | Knot-A2 (10.10.10.12) | Slave | Yes → `a1` |
| `knot/knot-A3.conf` | Knot-A3 (10.10.10.13) | Slave | Yes → `a1` |
| `knot/knot-B1.conf` | Knot-B1 (10.10.20.11) | Standby Master | Yes → `a1` (normal) |
| `knot/knot-B2.conf` | Knot-B2 (10.10.20.12) | Slave | Yes → `b1` |
| `knot/knot-B3.conf` | Knot-B3 (10.10.20.13) | Slave | Yes → `b1` |
| `knot/keys.conf` | all 6 | TSIG keys | — |
| `knot/domain.local.zone` | Knot-A1 only | initial zone data | — |

Key `knotc` operations you'll use day to day:

```bash
knotc conf-check                       # validate config before commit
knotc zone-status domain.local         # role, serial, last xfr/notify time
knotc zone-refresh domain.local        # force pull from configured master
knotc zone-retransfer domain.local     # force full AXFR (ignore serial)
knotc zone-notify domain.local         # force this node to send NOTIFY to its slaves
knotc zone-check domain.local          # validate zone file on disk
knotc zone-reload domain.local         # reload zone file from disk (master only)
knotc conf-begin / conf-set / conf-unset / conf-commit / conf-abort
```

---

## 6. dnsdist Configuration Map

| File | Node | Local pool (preferred) | Remote pool (fallback) |
|---|---|---|---|
| `dnsdist/dnsdist-A1.conf` | 10.10.10.16 | Knot-A2, Knot-A3 | Knot-B2, Knot-B3 |
| `dnsdist/dnsdist-A2.conf` | 10.10.10.17 | Knot-A2, Knot-A3 | Knot-B2, Knot-B3 |
| `dnsdist/dnsdist-B1.conf` | 10.10.20.16 | Knot-B2, Knot-B3 | Knot-A2, Knot-A3 |
| `dnsdist/dnsdist-B2.conf` | 10.10.20.17 | Knot-B2, Knot-B3 | Knot-A2, Knot-A3 |

Improvement over your original config: instead of `wrandom` +
`weight=1` (which still sends a small random % of traffic cross-site
*even when local servers are healthy*), this uses:

```lua
setServerPolicy(leastOutstanding)
addAction(PoolAvailableRule("local"), PoolAction("local"))
addAction(AllRule(), PoolAction("remote"))
```

`PoolAvailableRule("local")` is true only while at least one server in
`pool="local"` is passing health checks. This gives **deterministic**
local-first routing with automatic cross-site fallback only on total
local failure. Requires dnsdist ≥ 1.6 (`dnsdist --version` to confirm;
if older, tell me and I'll give you the weighted-pool equivalent).
Masters (A1/B1) are intentionally excluded as backends — they only ever
serve AXFR/IXFR, never client queries, keeping write-path load isolated.

---

## 7. keepalived Configuration Map

| File | Node | State | Priority | VRID | VIP |
|---|---|---|---|---|---|
| `keepalived/keepalived-A1.conf` | 10.10.10.16 | MASTER | 200 | 51 | 10.10.10.10 |
| `keepalived/keepalived-A2.conf` | 10.10.10.17 | BACKUP | 100 | 51 | 10.10.10.10 |
| `keepalived/keepalived-B1.conf` | 10.10.20.16 | MASTER | 200 | 52 | 10.10.20.10 |
| `keepalived/keepalived-B2.conf` | 10.10.20.17 | BACKUP | 100 | 52 | 10.10.20.10 |

Both VRRP instances use `chk_dnsdist` (from `scripts/check-dnsdist.sh`),
`weight -50` — if the check fails, priority drops from 200→150 (still
above BACKUP's 100... **note**: with these numbers a single failed
check does NOT hand over the VIP). If you want a single failed check to
immediately fail over, either raise `weight` to `-110` (below 100) or
lower BACKUP's priority. Recommended: set `weight -110` so any one
health-check failure hands off the VIP immediately — update both
`keepalived-A*.conf` and `keepalived-B*.conf` if you want this behavior.

`preempt_delay 30` avoids rapid flapping when the MASTER node's check
recovers — it waits 30s of sustained health before reclaiming the VIP.

---

## 8. Split-Brain Prevention (read this before touching production)

Three independent controls, layered:

1. **No dynamic-update ACLs anywhere.** Every ACL in this cluster grants
   only `transfer` or `notify` — never `update`. That means the *only*
   way zone content changes is an operator editing the zone file on
   whichever node is currently the master and running `knotc
   zone-reload`. Two nodes cannot both receive conflicting writes via
   the DNS protocol, because neither accepts writes via the protocol at
   all. This eliminates the most common cause of DNS split-brain
   entirely, at the cost of zone edits being a manual/scripted step
   rather than `nsupdate`.
2. **`role-guard.sh`** — run on any Knot node before editing its zone
   file by hand. It checks `knotc conf-get zone[domain.local].master`;
   if a master IS set (this node is a slave), it refuses to open the
   editor. This stops a human from editing the zone file on the wrong
   node.
3. **Scripted, order-safe promotion/failback** (`promote-site-b.sh`,
   `fence-old-master.sh`, `restore-site-a.sh`) — these always converge
   the *old* master to slave status pointed at the *new* master **before**
   the new master is ever unset, so there is never a window with two
   simultaneous masters. Where a brief window is unavoidable, the
   scripts force it to be "zero masters" (both slaves) rather than "two
   masters" — see comments inside `restore-site-a.sh`.

There is **no automatic** cross-site master failover in this design on
purpose. Automatic failover of a *writable* system based on a health
check is exactly what causes split-brain during network partitions
(both sides "think" they're isolated and promote themselves). Promotion
is a deliberate, scripted, human-confirmed action. Query-serving
failover (dnsdist pools, VRRP) *is* automatic, because reads are always
safe to fail over.

---

## 9. Operating Procedures

### 9.1 Normal health check
```bash
./scripts/cluster-status.sh
```
Expect: A1 shows `MASTER-CFG (none = MASTER)`, all others show a master
id, all serials identical.

### 9.2 Site-A disaster (A1 down) → promote B1
```bash
./scripts/promote-site-b.sh          # refuses if A1 still reachable
# ... incident ongoing, B1 now authoritative ...
```

### 9.3 A1 recovers → fence it immediately
```bash
./scripts/fence-old-master.sh        # forces A1 to slave(b1), resyncs
```
Run this **the moment** A1 is back on the network, before doing
anything else with it. Do not restart the old `knot.conf` on A1 as-is
without this step if it had `master:` unset from a prior manual change —
always re-point it at the current truth first.

### 9.4 Planned failback to A1
```bash
./scripts/restore-site-a.sh          # maintenance window, order-safe
```

### 9.5 Manual zone edit (only ever on the current master)
```bash
ssh root@10.10.10.11
/usr/local/bin/role-guard.sh edit    # opens $EDITOR, validates, reloads, notifies
```

### 9.6 WAN partition between sites (both sites still up locally)
Each site keeps serving reads locally (dnsdist pools are per-site and
don't require the WAN link). Knot-B1 keeps serving its last-known-good
zone as a slave (stale but safe — it simply stops getting fresh AXFR
until the link returns). **Do not** run `promote-site-b.sh` for a WAN
partition alone — A1 is still up and writable; promoting B1 too would
be split-brain. Only promote when A1/Site-A itself is actually down.

---

## 10. Testing Checklist

- [ ] `knotc conf-check` passes on all 6 nodes after any edit.
- [ ] Kill `knot` on A2: confirm dnsdist-A still resolves via A3 only
      (`dig @10.10.10.10 www.domain.local`).
- [ ] Kill `knot` on A2 **and** A3: confirm dnsdist-A automatically
      serves from B2/B3 (`PoolAvailableRule` fallback) — check
      `dnsdist -c /etc/dnsdist/dnsdist.conf` webserver `/jsonstat` or
      `showServers()` in the console.
- [ ] Kill `dnsdist` on DNSDist-A1: confirm VIP `10.10.10.10` migrates
      to DNSDist-A2 within ~2-6s (`ip a` on A2).
- [ ] Kill both dnsdist nodes at Site A: confirm a Site-A client configured
      with secondary `10.10.20.10` still resolves (simulates full site LB
      outage, relies on the client's own resolver retry/fallback).
- [ ] Full Site-A outage drill: stop all 3 Knot-A + both dnsdist-A VMs,
      run `promote-site-b.sh`, verify writes/edits work on B1, run
      `fence-old-master.sh` + `restore-site-a.sh` on recovery, confirm
      final serials match via `cluster-status.sh`.

---

## 11. Repo Layout

```
dns-ha-cluster/
├── README.md                  <- this file
├── knot/
│   ├── keys.conf               (deploy to all 6 knot nodes)
│   ├── knot-A1.conf .. knot-B3.conf
│   └── domain.local.zone       (initial data, load on A1 only)
├── dnsdist/
│   └── dnsdist-A1.conf, A2, B1, B2
├── keepalived/
│   └── keepalived-A1.conf, A2, B1, B2
└── scripts/
    ├── check-dnsdist.sh        (keepalived health check)
    ├── vrrp-notify.sh          (keepalived state-change logger)
    ├── role-guard.sh           (per-node: blocks edits unless master)
    ├── cluster-status.sh       (run from mgmt host: full cluster view)
    ├── promote-site-b.sh       (DR: promote B1)
    ├── fence-old-master.sh     (DR recovery: force old master to slave)
    └── restore-site-a.sh       (planned failback, order-safe)
```

All scripts assume passwordless SSH (key-based, `root@<ip>`) from a
management host to all 6 Knot nodes. Adjust the SSH user/sudo prefix at
the top of each script to match your environment if you don't manage as
root directly.
