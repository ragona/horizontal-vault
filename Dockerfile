FROM hashicorp/vault:latest

# Install dependencies (jq and curl)
RUN apk add --no-cache jq curl

# Copy configuration and entrypoint script
COPY config.hcl /vault/config/config.hcl
COPY entrypoint.sh /vault/entrypoint.sh
RUN chmod +x /vault/entrypoint.sh

# Create directories for persistent data and shared files (the key backup)
RUN mkdir -p /vault/data /vault/file

ENV VAULT_ADDR=http://127.0.0.1:8200
ENV VAULT_CONFIG_PATH=/vault/config/config.hcl

# Use the custom entrypoint that will start Vault and do init/unseal
ENTRYPOINT ["/vault/entrypoint.sh"]
