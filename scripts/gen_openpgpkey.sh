#!/usr/bin/env bash
# ==============================================================================
# Wharf OPENPGPKEY Record Generator
# ==============================================================================
# Generates DNS OPENPGPKEY (RFC 7929) records for email encryption.
#
# This allows email clients to automatically discover PGP keys by looking up
# DNS records, enabling encrypted email without manual key exchange.
#
# Usage:
#   ./gen_openpgpkey.sh <email> <public_key_file>
#
# Example:
#   ./gen_openpgpkey.sh jonathan@example.com ~/.gnupg/pubkey.asc
#
# Output:
#   The DNS record to add to your zone file.

set -euo pipefail

EMAIL="${1:-}"
PUBKEY_FILE="${2:-}"

# Check arguments
if [[ -z "$EMAIL" || -z "$PUBKEY_FILE" ]]; then
    echo "Usage: $0 <email> <public_key_file>" >&2
    exit 1
fi

# Check pubkey file exists
if [[ ! -f "$PUBKEY_FILE" ]]; then
    echo "Error: Public key file not found: $PUBKEY_FILE" >&2
    exit 1
fi

# Extract local part and domain from email
LOCAL_PART="${EMAIL%@*}"
DOMAIN="${EMAIL#*@}"

if [[ "$LOCAL_PART" == "$EMAIL" || -z "$DOMAIN" ]]; then
    echo "Error: Invalid email format: $EMAIL" >&2
    exit 1
fi

# RFC 7929: Hash the local part with SHA256, truncate to 28 octets (56 hex chars)
# The hash is of the lowercase UTF-8 representation
HASH=$(echo -n "${LOCAL_PART,,}" | openssl dgst -sha256 -binary | head -c 28 | xxd -p | tr -d '\n')

# Base64 encode the public key (removing ASCII armor if present)
# We need to strip the headers/footers and join lines
KEY_DATA=$(grep -v "^-" "$PUBKEY_FILE" | tr -d '\n')

# If the key is ASCII armored, we need to decode and re-encode for DNS
# For simplicity, we'll just use the raw base64 from the armor
if grep -q "BEGIN PGP" "$PUBKEY_FILE"; then
    # Extract just the base64 content
    KEY_DATA=$(sed -n '/^$/,/^-/p' "$PUBKEY_FILE" | grep -v "^-" | grep -v "^$" | tr -d '\n')
fi

echo "=== OPENPGPKEY Record Generator ==="
echo "Email:  $EMAIL"
echo "Domain: $DOMAIN"
echo "Hash:   $HASH"
echo ""
echo "DNS Record to add to your zone file:"
echo ""
echo "; OPENPGPKEY for $EMAIL"
echo "${HASH}._openpgpkey IN OPENPGPKEY ${KEY_DATA}"
echo ""
echo "Note: If the key is very long, you may need to split it into multiple"
echo "TXT strings (each max 255 chars) within the OPENPGPKEY record."
