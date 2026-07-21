#!/bin/bash
# Helper script to generate TSIG keys for the cluster

echo "Generating TSIG keys..."

mkdir -p ./keys
cd ./keys

echo "Generating tsig-site-sync..."
keymgr -t tsig-site-sync hmac-sha256 > tsig-site-sync.key

echo "Generating tsig-local-a..."
keymgr -t tsig-local-a hmac-sha256 > tsig-local-a.key

echo "Generating tsig-local-b..."
keymgr -t tsig-local-b hmac-sha256 > tsig-local-b.key

echo "Keys generated in ./keys directory."
echo "Copy the 'secret' values from these files into your knot.conf files."
