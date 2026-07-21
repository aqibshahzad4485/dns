# 01 Architecture & Design

## Overview
This architecture deploys a highly available, dual-site DNS infrastructure for private (local) networks not connected to the internet. The design leverages three critical software components:

1. **Knot DNS**: High-performance authoritative DNS server.
2. **dnsdist**: DNS, DOS, and abuse-aware load balancer.
3. **Keepalived**: Virtual IP (VIP) manager for high availability routing.

## Network Topology
The network consists of two fully routable, private subnets:
- **Site-A**: `10.10.10.0/24`
- **Site-B**: `10.10.20.0/24`

Clients in Site A use `10.10.10.10` (Site A VIP) and `10.10.20.10` (Site B VIP) as their primary and secondary DNS resolvers, respectively. Clients in Site B use the inverse.

## High Availability Design
### Layer 1: Keepalived (VIPs)
At each site, Keepalived runs on two dnsdist nodes to manage a local Virtual IP (VIP).
- If the primary dnsdist node fails, the secondary dnsdist node assumes the VIP within seconds.
- Clients experience zero downtime, as the VIP seamlessly moves between identical load balancers.

### Layer 2: dnsdist (Load Balancing)
`dnsdist` receives queries on the VIP and distributes them to the Knot DNS backend servers.
- **Local Preference**: dnsdist prefers backend Knot servers located in the *same* site.
- **Remote Fallback**: If all local Knot servers fail, dnsdist automatically routes queries across the site link to the Knot servers in the remote site.
- **Health Checks**: dnsdist actively monitors all backend Knot servers using synthesized `_dns-health.domain.local` A records.

### Layer 3: Knot DNS (Data Replication)
Zone data is replicated between all nodes using native DNS AXFR/IXFR transfers protected by TSIG.
- **Primary Master (Site A)**: `Knot-A1` holds the authoritative zone data and sends NOTIFY messages to its slaves.
- **Standby Master (Site B)**: `Knot-B1` acts as a slave during normal operations but can be promoted to Primary Master in a disaster.
- **Slaves**: `Knot-A2`, `Knot-A3`, `Knot-B2`, and `Knot-B3` pull zone data from their respective site masters.

## Data Flow
1. Client in Site A queries `10.10.10.10` (VIP-A).
2. `DNSDist-A1` receives the query on port 53.
3. `DNSDist-A1` forwards the query to `Knot-A2` or `Knot-A3` locally.
4. `Knot-A2` resolves the query and returns the answer to `DNSDist-A1`.
5. `DNSDist-A1` caches the response (Packet Cache) and returns it to the client.

## Security Model
- **TSIG Authentication**: All zone transfers and NOTIFY messages are cryptographically signed using TSIG keys.
- **Access Control Lists (ACLs)**: Strict ACLs ensure Knot only accepts transfers and notifications from designated IPs.
- **dnsdist Mitigation**: Rate-limiting and QType restrictions (e.g., dropping `ANY` queries) protect Knot from internal DOS or misbehaving applications.
