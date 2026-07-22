# 03 PKI and TSIG Security

To secure zone transfers (AXFR/IXFR) and NOTIFY messages, we use Transaction Signatures (TSIG).

## TSIG Key Structure
We will use two distinct TSIG keys to logically separate communication paths:

1. `tsig-site-sync`: Used exclusively for communication between Primary Master (`Knot-A1`) and Standby Master (`Knot-B1`).
2. `tsig-master-slave`: A unified key used for all communication between Masters (`A1`, `B1`) and Slaves (`A2`, `A3`, `B2`, `B3`). This shared key allows any slave to easily switch its sync source between A1 and B1 if a master goes offline.

## Generating TSIG Keys
You can generate keys on any Linux machine using `keymgr` (bundled with Knot).

```bash
keymgr -t tsig-site-sync hmac-sha256
keymgr -t tsig-master-slave hmac-sha256
```

## Adding Keys to Knot Configuration
In `knot.conf`, keys are defined in the `key:` block.

Example:
```yaml
key:
  - id: tsig-site-sync
    algorithm: hmac-sha256
    secret: "base64_encoded_secret_here"
  
  - id: tsig-master-slave
    algorithm: hmac-sha256
    secret: "base64_encoded_secret_here"
```

These keys are then referenced in the `remote:` blocks and `acl:` blocks to enforce authenticated communication.

## Master Switching for Slaves
Because all slaves use the unified `tsig-master-slave` key, switching a slave's master from A1 to B1 (or vice versa) is extremely easy. You only need to change the `master:` directive in the zone configuration or use the provided `scripts/switch-slave-master.sh` script to dynamically flip the master without recreating keys or restarting the service.
