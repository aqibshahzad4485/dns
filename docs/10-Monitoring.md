# 10 Monitoring & Observability

To achieve a "single pane of glass" Grafana dashboard, we recommend the following monitoring stack:

## 1. System Metrics (Prometheus Node Exporter)
Install `node_exporter` on all 10 servers to monitor CPU, RAM, Disk, and Network IO.

## 2. Knot DNS Metrics (knot_exporter)
Install `knot_exporter` on all 6 Knot servers. This exposes Knot statistics (queries, zone transfers, memory) to Prometheus.

```bash
# Example
knotc conf-set server.listen '127.0.0.1@53'
# Enable stats module in Knot
knotc conf-set mod-stats.id 'default'
```

## 3. dnsdist Metrics
`dnsdist` natively exposes metrics via its Web UI. You can scrape these directly in Prometheus.
Prometheus config:
```yaml
scrape_configs:
  - job_name: 'dnsdist'
    static_configs:
      - targets: ['10.10.10.16:8083', '10.10.10.17:8083', '10.10.20.16:8083', '10.10.20.17:8083']
```

## 4. Keepalived Metrics
Use a community exporter like `keepalived-exporter` to track VIP state (Master/Backup) and VRRP transitions.

## 5. Query Logging (dnstap to ClickHouse)
Knot is configured to write `dnstap` logs to `/tmp/dnstap.sock`.
To visualize every DNS query in Grafana:

1. Install **Vector** (by DataDog) on all 6 Knot servers.
2. Configure Vector to read from the UNIX socket:
```toml
[sources.dnstap_in]
type = "dnstap"
socket_path = "/tmp/dnstap.sock"

[sinks.clickhouse_out]
type = "clickhouse"
inputs = ["dnstap_in"]
endpoint = "http://clickhouse-server:8123"
database = "dns_logs"
table = "queries"
```
3. Connect Grafana to ClickHouse using the official ClickHouse plugin.
4. You can now build dashboards showing Top Queried Domains, Top Clients, and NXDOMAIN spikes.
