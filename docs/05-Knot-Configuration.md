# 05 Knot DNS Configuration

This document explains the logic behind the Knot configurations. The actual configuration files are located in the `configs/knot/` directory of this repository.

## Roles

### 1. Primary Master (Knot-A1)
- Authoritative for the zone.
- Holds the master zone file (`/var/lib/knot/domain.local.zone`).
- Configured to `notify` the local slaves (`A2`, `A3`) and the Standby Master (`B1`).
- ACL allows zone transfers `transfer` out to `A2`, `A3`, and `B1`.
- ACL allows `notify` only from `B1` (in the event B1 is promoted).

### 2. Standby Master (Knot-B1)
- Acts as a slave to `A1` during normal operations.
- Receives zone transfers and notifications from `A1`.
- Configured to `notify` its local slaves (`B2`, `B3`) and `A1` (in case B1 is promoted to master).
- In the event of Site A failing, we will use `knotc` to dynamically remove the `master` designation from `B1`, elevating it to Primary Master without editing text files.

### 3. Local Slaves (A2, A3, B2, B3)
- Simple slave configuration.
- A2 and A3 sync strictly from A1.
- B2 and B3 sync strictly from B1.
- This hierarchy prevents excessive cross-WAN zone transfers. Only A1 -> B1 traverses the site link.

## Logging & dnstap
All nodes load the `mod-dnstap` module.
The sink is configured to `"unix:/tmp/dnstap.sock"`.
In production, a tool like `dnstap-receiver` or Vector listens on this socket, parses the protobuf messages, and ships the query/response logs to ClickHouse.

## TSIG Security
Keys are heavily utilized.
- `A1` -> `B1` uses `tsig-site-sync`
- `A1` -> `A2/A3` uses `tsig-local-a`
- `B1` -> `B2/B3` uses `tsig-local-b`
