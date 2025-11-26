#!/usr/bin/env bash
# ==============================================================================
# Wharf Environment Detector
# ==============================================================================
# Determines if a domain is on dedicated or shared hosting by checking the PTR
# (reverse DNS) record. This helps choose the correct DNS template.
#
# Usage:
#   ./detect_env.sh <domain> <ip>
#
# Example:
#   ./detect_env.sh example.com 192.0.2.1
#
# Output:
#   - "dedicated" if PTR matches domain (use maximalist.tpl)
#   - "shared" if PTR is generic (use shared.tpl)

set -euo pipefail

DOMAIN="${1:-}"
IP="${2:-}"

# Check arguments
if [[ -z "$DOMAIN" || -z "$IP" ]]; then
    echo "Usage: $0 <domain> <ip>" >&2
    exit 1
fi

# Check for dig
if ! command -v dig &> /dev/null; then
    echo "Error: dig is required but not installed." >&2
    echo "Install with: sudo apt install bind9-dnsutils (or equivalent)" >&2
    exit 1
fi

echo "=== Wharf Environment Analysis ==="
echo "Domain: $DOMAIN"
echo "IP:     $IP"
echo ""

# Perform reverse DNS lookup
PTR=$(dig +short -x "$IP" 2>/dev/null | head -1 | sed 's/\.$//')

if [[ -z "$PTR" ]]; then
    echo "Warning: No PTR record found for $IP"
    echo ""
    echo "Recommendation: Use 'shared.tpl' template (conservative choice)"
    echo "Reason: Without PTR, we cannot verify IP ownership"
    exit 0
fi

echo "PTR:    $PTR"
echo ""

# Check if PTR matches the domain
# We check if the domain is contained in the PTR
if echo "$PTR" | grep -qi "$DOMAIN"; then
    echo ">>> CONCLUSION: DEDICATED Environment Detected"
    echo ""
    echo "Recommendation: Use 'maximalist.tpl' or 'standard.tpl' template"
    echo "Reason: The PTR record ($PTR) matches your domain"
    echo ""
    echo "You can safely use:"
    echo "  - SSHFP records (you control the host keys)"
    echo "  - TLSA/DANE records (you control the certificates)"
    echo "  - Strict SPF (-all) instead of soft fail (~all)"
    echo "  - Direct A records for FTP (explicit IP binding)"
else
    echo ">>> CONCLUSION: SHARED/VIRTUAL Environment Detected"
    echo ""
    echo "Recommendation: Use 'shared.tpl' template"
    echo "Reason: PTR ($PTR) is generic/provider-owned"
    echo ""
    echo "Warnings for this environment:"
    echo "  - Do NOT use SSHFP records (host keys may change)"
    echo "  - Use CNAME for FTP (follows IP changes on migration)"
    echo "  - Include provider's SPF (include:%provider%)"
    echo "  - Shared IP reputation may affect email deliverability"
fi
