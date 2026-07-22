# 03 PKI and TSIG Security

To secure zone transfers (AXFR/IXFR) and NOTIFY messages, we use Transaction Signatures (TSIG).

## TSIG Key Structure
We will use three distinct TSIG keys to logically separate communication paths:

1. `tsig-site-sync`: Used exclusively for communication between Primary Master (`Knot-A1`) and Standby Master (`Knot-B1`).
2. `tsig-local-a`: Used for communication between `Knot-A1` and its local slaves (`Knot-A2`, `Knot-A3`).
3. `tsig-local-b`: Used for communication between `Knot-B1` and its local slaves (`Knot-B2`, `Knot-B3`).

## Generating TSIG Keys
You can generate keys on any Linux machine using `keymgr` (bundled with Knot).

```bash
keymgr -t tsig-site-sync hmac-sha256
keymgr -t tsig-local-a hmac-sha256
keymgr -t tsig-local-b hmac-sha256
```

## Adding Keys to Knot Configuration
In `knot.conf`, keys are defined in the `key:` block.

Example:
```yaml
key:
  - id: tsig-site-sync
    algorithm: hmac-sha256
    secret: "base64_encoded_secret_here"
  
  - id: tsig-local-a
    algorithm: hmac-sha256
    secret: "base64_encoded_secret_here"
  
  - id: tsig-local-b
    algorithm: hmac-sha256
    secret: "base64_encoded_secret_here"
```

These keys are then referenced in the `remote:` blocks and `acl:` blocks to enforce authenticated communication.

## Split-Brain Prevention Note
Using distinct TSIG keys ensures that if Site B is forcefully promoted, local Site A slaves will not accidentally start syncing from Site B unless explicitly reconfigured to do so. This creates a natural "fencing" mechanism.
