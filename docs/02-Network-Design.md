# 02 Network Design & VIPs

## IP Addressing Plan

### Site A (Network: 10.10.10.0/24)
| Hostname | IP Address | Role |
| :--- | :--- | :--- |
| **DNSDist-AVIP** | `10.10.10.10` | Virtual IP for Site A Clients |
| **Knot-A1** | `10.10.10.11` | Primary Master |
| **Knot-A2** | `10.10.10.12` | Local Slave 1 |
| **Knot-A3** | `10.10.10.13` | Local Slave 2 |
| **DNSDist-A1** | `10.10.10.16` | Load Balancer (Master for VIP-A) |
| **DNSDist-A2** | `10.10.10.17` | Load Balancer (Backup for VIP-A) |

### Site B (Network: 10.10.20.0/24)
| Hostname | IP Address | Role |
| :--- | :--- | :--- |
| **DNSDist-BVIP** | `10.10.20.10` | Virtual IP for Site B Clients |
| **Knot-B1** | `10.10.20.11` | Standby Master (Slave to A1 normally) |
| **Knot-B2** | `10.10.20.12` | Local Slave 1 |
| **Knot-B3** | `10.10.20.13` | Local Slave 2 |
| **DNSDist-B1** | `10.10.20.16` | Load Balancer (Master for VIP-B) |
| **DNSDist-B2** | `10.10.20.17` | Load Balancer (Backup for VIP-B) |

## Client Configuration

Clients should be configured via DHCP (or statically) to use both VIPs. The order depends on their physical/logical location.

**Site A DHCP Options:**
- DNS Server 1: `10.10.10.10`
- DNS Server 2: `10.10.20.10`

**Site B DHCP Options:**
- DNS Server 1: `10.10.20.10`
- DNS Server 2: `10.10.10.10`

## Routing Considerations
Since this is a fully locally hosted network with no internet access:
1. Ensure full bidirectional routing between `10.10.10.0/24` and `10.10.20.0/24`.
2. Ensure no firewalls are blocking port `53` (TCP/UDP) between the subnets.
3. Keepalived uses VRRP (IP protocol 112). Ensure VRRP multicasts (`224.0.0.18`) are permitted on the local L2 segments. VRRP does *not* cross the routed boundary between Site A and Site B, which is correct design.
