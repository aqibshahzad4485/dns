#!/bin/bash
# Helper script to generate TSIG keys for the cluster

echo "Generating TSIG keys..."

mkdir -p ./keys
cd ./keys

echo "Generating tsig-site-sync..."
keymgr -t tsig-site-sync hmac-sha256 > tsig-site-sync.key

echo "Generating tsig-master-slave..."
keymgr -t tsig-master-slave hmac-sha256 > tsig-master-slave.key

echo "Keys generated in ./keys directory."
echo "Copy the 'secret' values from these files into your knot.conf files."
