# 07 dnsdist Configuration

## Purpose
`dnsdist` acts as a highly-available load balancer in front of Knot DNS. It provides:
1. Intelligent load balancing.
2. Cross-site failover.
3. Packet caching to reduce load on Knot.
4. Security filtering.

## Installation
```bash
sudo apt update
sudo apt install -y dnsdist
```

## Logic and Policies

### Load Balancing (wrandom)
We use the `wrandom` (weighted random) policy.
- Local site Knot servers are given `weight=100`.
- Remote site Knot servers are given `weight=1`.

This effectively pins queries to the local site under normal operations. If *all* local nodes fail health checks, dnsdist will gracefully fallback to the remote nodes with `weight=1`.

### Health Checks
Each backend is configured with `checkName="_dns-health.domain.local"`. dnsdist will constantly query this record.

### Packet Cache
A packet cache of 100,000 entries is defined. This dramatically improves performance for repeated queries and shields the backend servers during query spikes.

### Security Rules
- `MaxQPSIPRule(1000)`: Drops queries from a single IP if they exceed 1000 QPS, mitigating DOS.
- `QTypeRule(DNSQType.ANY)`: Refuses `ANY` queries, a common vector for amplification attacks.

### Web UI
The Web UI is enabled on port `8083`. You can access it via `http://<dnsdist-ip>:8083` to view real-time statistics and server health.
