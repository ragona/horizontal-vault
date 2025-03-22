#!/bin/bash
# Remove any existing data vault container (example: vault-data-1)
docker rm -f vault-data-1 || true

# Run a data vault container in data mode.
# It mounts the same seed_data volume so it can access the backup file.
docker run --name vault-data-1 \
  -p 8201:8200 \
  -v "$PWD/seed_data:/vault/file" \
  -e VAULT_MODE=data \
  horizontal-vault
