#!/bin/sh
set -e
set +x

# Run initialization logic in background
(
  echo "Waiting for Vault to become available..."
  until curl -s http://127.0.0.1:8200/v1/sys/health | grep -q '"sealed":'; do
      sleep 1
  done
  echo "Vault is up."

  # Optionally remove the config file to avoid token helper issues.
  rm "/vault/config/config.hcl"

  HEALTH=$(curl -s http://127.0.0.1:8200/v1/sys/health)

  case "$VAULT_MODE" in
    base)
      echo "Running in BASE mode..."
      if echo "$HEALTH" | grep -q '"initialized":false'; then
        echo "Vault is not initialized. Initializing in BASE mode..."
        INIT_OUTPUT=$(vault operator init -key-shares=1 -key-threshold=1 -format=json)
        UNSEAL_KEY=$(echo "$INIT_OUTPUT" | jq -r '.unseal_keys_b64[0]')
        ROOT_TOKEN=$(echo "$INIT_OUTPUT" | jq -r '.root_token')

        echo "Unsealing Vault..."
        vault operator unseal "$UNSEAL_KEY"
        export VAULT_TOKEN="$ROOT_TOKEN"

        echo "Dumping root credentials to file..."
        echo "{\"root_token\": \"$ROOT_TOKEN\", \"unseal_key\": \"$UNSEAL_KEY\"}" > /vault/file/root_creds.json
      else
        echo "Vault is already initialized in BASE mode."
        if [ -f /vault/file/root_creds.json ]; then
          ROOT_TOKEN=$(jq -r '.root_token' /vault/file/root_creds.json)
          export VAULT_TOKEN="$ROOT_TOKEN"
          if echo "$HEALTH" | grep -q '"sealed":true'; then
            echo "Vault is sealed in BASE mode. Unsealing..."
            UNSEAL_KEY=$(jq -r '.unseal_key' /vault/file/root_creds.json)
            vault operator unseal "$UNSEAL_KEY"
          fi
        else
          echo "Error: Vault is initialized but root credentials file is missing in BASE mode."
          exit 1
        fi
      fi
      ;;
    seed)
      echo "Running in SEED mode..."
      if echo "$HEALTH" | grep -q '"initialized":false'; then
        echo "Error: Vault is not initialized in SEED mode. Run BASE mode first."
        exit 1
      else
        if [ -f /vault/file/root_creds.json ]; then
          ROOT_TOKEN=$(jq -r '.root_token' /vault/file/root_creds.json)
          export VAULT_TOKEN="$ROOT_TOKEN"
          if echo "$HEALTH" | grep -q '"sealed":true'; then
            echo "Vault is sealed in SEED mode. Unsealing..."
            UNSEAL_KEY=$(jq -r '.unseal_key' /vault/file/root_creds.json)
            vault operator unseal "$UNSEAL_KEY"
          fi
        else
          echo "Error: Root credentials file missing in SEED mode."
          exit 1
        fi
      fi

      echo "Enabling transit secrets engine..."
      vault secrets enable transit || echo "Transit engine already enabled."

      echo "Creating transit key 'shared-key'..."
      vault write -f transit/keys/shared-key exportable=true allow_plaintext_backup=true

      echo "Backing up transit key 'shared-key'..."
      vault read -field=backup transit/backup/shared-key > /vault/file/shared-key.backup

      echo "Seed vault ready. Transit key backup stored at /vault/file/shared-key.backup"
      echo "Contents of /vault/file:"
      ls -l /vault/file
      echo "Backup file (first 100 bytes):"
      head -c 100 /vault/file/shared-key.backup
      echo ""
      echo "Root Token: $ROOT_TOKEN"
      echo "Unseal Key: $UNSEAL_KEY"
      ;;
    data)
      echo "Running in DATA mode..."
      if echo "$HEALTH" | grep -q '"initialized":false'; then
        echo "Error: Vault is not initialized in DATA mode. Run BASE mode first."
        exit 1
      else
        if [ -f /vault/file/root_creds.json ]; then
          ROOT_TOKEN=$(jq -r '.root_token' /vault/file/root_creds.json)
          export VAULT_TOKEN="$ROOT_TOKEN"
          if echo "$HEALTH" | grep -q '"sealed":true'; then
            echo "Vault is sealed in DATA mode. Unsealing..."
            UNSEAL_KEY=$(jq -r '.unseal_key' /vault/file/root_creds.json)
            vault operator unseal "$UNSEAL_KEY"
          fi
        else
          echo "Error: Root credentials file missing in DATA mode."
          exit 1
        fi
      fi

      echo "Enabling transit secrets engine..."
      vault secrets enable transit || echo "Transit engine already enabled."

      if [ -f /vault/file/shared-key.backup ]; then
        BACKUP=$(cat /vault/file/shared-key.backup)
        echo "Restoring transit key 'shared-key' from backup..."
        vault write transit/restore/shared-key backup="$BACKUP"
        echo "Data vault ready with restored transit key 'shared-key'."
      else
        echo "Error: shared-key backup not found at /vault/file/shared-key.backup"
        exit 1
      fi
      ;;
    *)
      echo "Error: VAULT_MODE must be set to 'base', 'seed', or 'data'"
      exit 1
      ;;
  esac
) &

# Start Vault server in the foreground; this becomes the main process.
exec vault server -config=/vault/config/config.hcl
