# DNS High Availability Cluster Guide

Welcome to the comprehensive guide for deploying a highly available DNS cluster across two distinct sites using **Knot DNS**, **dnsdist**, and **Keepalived**.

This architecture provides active-active and active-passive redundancy at multiple layers (DNS load balancing, VRRP VIP failover, and DNS zone replication) to ensure continuous resolution services even during complete site failures.

## Table of Contents

### Documentation
- [01 Architecture & Design](docs/01-Architecture.md)
- [02 Network Design & VIPs](docs/02-Network-Design.md)
- [03 PKI and TSIG Security](docs/03-PKI-and-TSIG.md)
- [04 Knot DNS Installation](docs/04-Knot-Installation.md)
- [05 Knot DNS Configuration](docs/05-Knot-Configuration.md)
- [06 Zone Files & Templates](docs/06-Zone-Files.md)
- [07 dnsdist Configuration](docs/07-dnsdist.md)
- [08 Keepalived Configuration](docs/08-Keepalived.md)
- [09 Failover and Split-Brain](docs/09-Failover-and-SplitBrain.md)
- [10 Monitoring & Observability](docs/10-Monitoring.md)
- [11 Systemd and Operations](docs/11-Systemd-and-Operations.md)

### Configurations
- [configs/knot/](configs/knot/)
- [configs/dnsdist/](configs/dnsdist/)
- [configs/keepalived/](configs/keepalived/)

### Scripts
- [scripts/](scripts/) - Contains manual promotion/demotion and cluster management scripts.

## Quick Start
1. Review the **Architecture** and **Network Design** documents.
2. Generate your TSIG keys using `scripts/generate-tsig.sh`.
3. Install Knot, dnsdist, and Keepalived on all respective nodes.
4. Apply the configurations from the `configs/` directory.
5. Setup monitoring via ClickHouse and Grafana as detailed in the monitoring document.
