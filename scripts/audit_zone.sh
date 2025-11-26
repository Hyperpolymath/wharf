#!/usr/bin/env bash
# ==============================================================================
# Wharf Zone Auditor
# ==============================================================================
# Audits a DNS zone file for security issues and modern best practices.
#
# Checks:
# - OWASP-recommended exclusions (no HINFO, RP, TXT version leaks)
# - Modern requirements (SPF, DMARC, CAA)
# - Security records (TLSA, SSHFP)
# - BIND syntax validation (if named-checkzone available)
#
# Usage:
#   ./audit_zone.sh <zone_file> <domain>
#
# Example:
#   ./audit_zone.sh dist/example.com.db example.com

set -euo pipefail

ZONE_FILE="${1:-}"
DOMAIN="${2:-}"

# Check arguments
if [[ -z "$ZONE_FILE" || -z "$DOMAIN" ]]; then
    echo "Usage: $0 <zone_file> <domain>" >&2
    exit 1
fi

# Check file exists
if [[ ! -f "$ZONE_FILE" ]]; then
    echo "Error: Zone file not found: $ZONE_FILE" >&2
    exit 1
fi

echo "=== Wharf Zone Security Audit ==="
echo "File:   $ZONE_FILE"
echo "Domain: $DOMAIN"
echo ""

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

# Helper function for check results
check_pass() {
    echo "[PASS] $1"
    ((PASS_COUNT++))
}

check_warn() {
    echo "[WARN] $1"
    ((WARN_COUNT++))
}

check_fail() {
    echo "[FAIL] $1"
    ((FAIL_COUNT++))
}

echo "--- Security Exclusions (OWASP) ---"

# Check for HINFO (information leakage)
if grep -qi "HINFO" "$ZONE_FILE"; then
    check_fail "HINFO record found - reveals OS/CPU info to attackers"
else
    check_pass "No HINFO records (good - prevents information leakage)"
fi

# Check for RP (Responsible Person - spam magnet)
if grep -qi "IN[[:space:]]*RP[[:space:]]" "$ZONE_FILE"; then
    check_warn "RP record found - may attract spam"
else
    check_pass "No RP records (good - reduces spam exposure)"
fi

# Check for TXT version leaks
if grep -qi "v=[0-9]" "$ZONE_FILE" | grep -qiv "v=spf1\|v=DKIM1\|v=DMARC1\|v=STSv1\|v=BIMI1\|v=TLSRPTv1"; then
    check_warn "Potential version information in TXT records"
else
    check_pass "No obvious version leaks in TXT records"
fi

echo ""
echo "--- Modern Email Requirements ---"

# Check for SPF
if grep -qi "v=spf1" "$ZONE_FILE"; then
    check_pass "SPF record found"
    # Check for hard fail
    if grep -qi "v=spf1.*-all" "$ZONE_FILE"; then
        check_pass "SPF uses hard fail (-all)"
    elif grep -qi "v=spf1.*~all" "$ZONE_FILE"; then
        check_warn "SPF uses soft fail (~all) - consider upgrading to -all"
    fi
else
    check_fail "No SPF record - emails will likely be marked as spam"
fi

# Check for DMARC
if grep -qi "_dmarc" "$ZONE_FILE"; then
    check_pass "DMARC record found"
    # Check DMARC policy
    if grep -qi "p=reject" "$ZONE_FILE"; then
        check_pass "DMARC policy is 'reject' (strictest)"
    elif grep -qi "p=quarantine" "$ZONE_FILE"; then
        check_pass "DMARC policy is 'quarantine' (recommended)"
    elif grep -qi "p=none" "$ZONE_FILE"; then
        check_warn "DMARC policy is 'none' - consider upgrading to quarantine/reject"
    fi
else
    check_fail "No DMARC record - email authentication incomplete"
fi

# Check for DKIM
if grep -qi "_domainkey" "$ZONE_FILE"; then
    check_pass "DKIM selector record found"
else
    check_warn "No DKIM record - email signing not configured"
fi

# Check for MTA-STS
if grep -qi "_mta-sts" "$ZONE_FILE"; then
    check_pass "MTA-STS record found (email transport security)"
else
    check_warn "No MTA-STS record - consider adding for email security"
fi

echo ""
echo "--- Certificate Authority Authorization ---"

# Check for CAA
if grep -qi "CAA" "$ZONE_FILE"; then
    check_pass "CAA records found"
    # Check for issuewild
    if grep -qi 'issuewild[[:space:]]*";"' "$ZONE_FILE"; then
        check_pass "Wildcard issuance is blocked"
    elif grep -qi "issuewild" "$ZONE_FILE"; then
        check_warn "Wildcard issuance is allowed - ensure this is intentional"
    fi
else
    check_fail "No CAA records - any CA can issue certificates for this domain"
fi

echo ""
echo "--- Modern Enhancements ---"

# Check for HTTPS/SVCB
if grep -qi "HTTPS\|SVCB" "$ZONE_FILE"; then
    check_pass "HTTPS/SVCB records found (HTTP/3 & ECH support)"
else
    check_warn "No HTTPS/SVCB records - consider adding for HTTP/3 support"
fi

# Check for TLSA (DANE)
if grep -qi "TLSA" "$ZONE_FILE"; then
    check_pass "TLSA records found (DANE certificate pinning)"
else
    check_warn "No TLSA records - consider adding for certificate validation"
fi

# Check for SSHFP
if grep -qi "SSHFP" "$ZONE_FILE"; then
    check_pass "SSHFP records found (SSH key fingerprints)"
else
    check_warn "No SSHFP records - consider adding for SSH verification"
fi

# Check for SRV (service discovery)
if grep -qi "SRV" "$ZONE_FILE"; then
    check_pass "SRV records found (service discovery)"
else
    check_warn "No SRV records - consider adding for client auto-configuration"
fi

echo ""
echo "--- BIND Syntax Check ---"

# Run named-checkzone if available
if command -v named-checkzone &> /dev/null; then
    if named-checkzone "$DOMAIN" "$ZONE_FILE" > /dev/null 2>&1; then
        check_pass "BIND syntax validation passed"
    else
        check_fail "BIND syntax validation failed"
        echo "  Run: named-checkzone $DOMAIN $ZONE_FILE"
    fi
else
    echo "[SKIP] named-checkzone not installed"
fi

echo ""
echo "=== Audit Summary ==="
echo "Passed: $PASS_COUNT"
echo "Warnings: $WARN_COUNT"
echo "Failed: $FAIL_COUNT"
echo ""

if [[ $FAIL_COUNT -gt 0 ]]; then
    echo "Result: FAILED - Critical issues found"
    exit 1
elif [[ $WARN_COUNT -gt 0 ]]; then
    echo "Result: PASSED with warnings"
    exit 0
else
    echo "Result: PASSED - Zone meets security standards"
    exit 0
fi
