# 06 Zone Files & Templates

## Zone Storage
By default, Knot stores zone files in `/var/lib/knot/`.
On the **Primary Master (A1)**, the zone file is loaded from text.
On the **Slaves**, the zone files are stored as binary journals by default. However, we set `file: "%s.zone"` in the template so they are periodically flushed to text for easy inspection.

## Health Check Record
To allow `dnsdist` to monitor the health of the backend Knot servers, we add a specific health check record to the zone.

```dns
_dns-health     IN      A       127.0.0.1
```
`dnsdist` will query this record every second. If it receives a valid response, the backend is marked `UP`. If it fails, it is marked `DOWN`.

## Example Zone File (`domain.local.zone`)
Located in the `zones/` directory of this repo.

```dns
$ORIGIN domain.local.
$TTL 3600

@       IN      SOA     ns1.domain.local. admin.domain.local. (
                        2026072101 ; Serial
                        3600       ; Refresh
                        1800       ; Retry
                        604800     ; Expire
                        86400      ; Minimum TTL
)

        IN      NS      ns1.domain.local.
        IN      NS      ns2.domain.local.

ns1     IN      A       10.10.10.10
ns2     IN      A       10.10.20.10

; Health check record for dnsdist
_dns-health IN  A       127.0.0.1

; Example records
router  IN      A       10.10.10.1
server1 IN      A       10.10.10.100
```
