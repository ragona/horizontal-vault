#!/bin/bash
set -e

# Ensure VAULT_TOKEN is set
if [ -z "$VAULT_TOKEN" ]; then
  echo "Error: VAULT_TOKEN environment variable must be set (use the root token from the seed vault)."
  exit 1
fi

# The plaintext message to encrypt
PLAINTEXT="Hello Vault!"
PLAINTEXT_B64=$(echo -n "$PLAINTEXT" | base64)

echo "Plaintext: $PLAINTEXT"
echo "Plaintext (base64): $PLAINTEXT_B64"

# Encrypt using the seed vault at port 8200
export VAULT_ADDR=http://127.0.0.1:8201
echo "Encrypting using seed vault at ${VAULT_ADDR}..."
CIPHERTEXT=$(vault write -field=ciphertext transit/encrypt/shared-key plaintext="$PLAINTEXT_B64")
echo "Ciphertext: $CIPHERTEXT"

# Decrypt using the data vault at port 8201
export VAULT_ADDR=http://127.0.0.1:8201
echo "Decrypting using data vault at ${VAULT_ADDR}..."
DECRYPTED_B64=$(vault write -field=plaintext transit/decrypt/shared-key ciphertext="$CIPHERTEXT")
DECRYPTED=$(echo "$DECRYPTED_B64" | base64 --decode)
echo "Decrypted text: $DECRYPTED"
