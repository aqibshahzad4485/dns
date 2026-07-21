# 04 Knot DNS Installation

This guide assumes Debian or Ubuntu based systems, which are the standard for Knot DNS deployments.

## 1. Add CZ.NIC Repository
Knot DNS is developed by CZ.NIC. To get the latest stable version, add their official repository.

```bash
sudo apt update
sudo apt install -y apt-transport-https lsb-release ca-certificates wget curl

sudo wget -O /usr/share/keyrings/cznic-archive-keyring.gpg https://packages.cz.nic.cz/apt/cznic-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/cznic-archive-keyring.gpg] https://packages.cz.nic.cz/apt/cznic-archive-keyring.gpg $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/cznic.list

sudo apt update
```

## 2. Install Knot DNS
Install the core Knot package, utilities, and the dnstap module.

```bash
sudo apt install -y knot knot-dnsutils knot-module-dnstap
```

## 3. Verify Installation
Ensure `knotc` is available and check the version.

```bash
knotc --version
```

## 4. Prepare Storage
Ensure the Knot storage directory exists and has the correct permissions.

```bash
sudo mkdir -p /var/lib/knot
sudo chown -R knot:knot /var/lib/knot
sudo chmod 770 /var/lib/knot
```

Repeat this process on all 6 Knot DNS nodes (`A1`, `A2`, `A3`, `B1`, `B2`, `B3`).
