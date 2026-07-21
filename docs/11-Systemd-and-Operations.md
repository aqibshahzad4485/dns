# 11 Systemd and Operations

## Service Management

### Knot DNS
```bash
# Start/Stop/Restart
sudo systemctl start knot
sudo systemctl stop knot
sudo systemctl restart knot

# Reload config without stopping resolution
sudo systemctl reload knot

# View logs
sudo journalctl -u knot -f
```

### dnsdist
```bash
sudo systemctl restart dnsdist
sudo journalctl -u dnsdist -f
```

### Keepalived
```bash
sudo systemctl restart keepalived
sudo journalctl -u keepalived -f
```

## Day-to-Day knotc Commands

`knotc` is the primary CLI tool for interacting with the Knot server.

### View Zone Status
```bash
knotc zone-status domain.local
```

### Reload a Zone File
If you manually edit `/var/lib/knot/domain.local.zone` on `Knot-A1`:
```bash
knotc zone-reload domain.local
```
This automatically triggers a NOTIFY to all slaves.

### Force a Zone Transfer
If a slave is out of sync, force it to pull from its master:
```bash
knotc zone-retransfer domain.local
```

### Dynamic Configuration
Avoid editing `/etc/knot/knot.conf` manually if possible. Use the CLI:
```bash
knotc conf-begin
knotc conf-set zone[domain.local].master 'site_b_primary'
knotc conf-commit
```
