#!/bin/bash
# Remove any existing seed container
docker rm -f vault-seed 2>/dev/null || true

# Create a host directory to store the key backup
rm -rf seed_data
mkdir -p seed_data

# Run the seed vault container in seed mode
docker run --name vault-seed \
  -p 8200:8200 \
  -v "$PWD/seed_data:/vault/file" \
  -e VAULT_MODE=seed \
  horizontal-vault
