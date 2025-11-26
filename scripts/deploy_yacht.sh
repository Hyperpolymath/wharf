#!/usr/bin/env bash
# ==============================================================================
# Wharf Yacht Deployment Script
# ==============================================================================
# Deploys the Yacht Agent and initial configuration to a remote server.
#
# Prerequisites:
#   - SSH access to the target server (root or sudo)
#   - Target should be running a supported OS (Fedora CoreOS, Wolfi, Debian)
#   - Nebula certificates generated via 'just gen-yacht-cert'
#
# Usage:
#   ./deploy_yacht.sh <target_ip> [ssh_user]
#
# Example:
#   ./deploy_yacht.sh 192.0.2.1 root

set -euo pipefail

TARGET_IP="${1:-}"
SSH_USER="${2:-root}"

# Check arguments
if [[ -z "$TARGET_IP" ]]; then
    echo "Usage: $0 <target_ip> [ssh_user]" >&2
    exit 1
fi

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
AGENT_BINARY="$PROJECT_DIR/target/release/yacht-agent"
NEBULA_DIR="$PROJECT_DIR/infra/nebula"

echo "=== Wharf Yacht Deployment ==="
echo "Target: $SSH_USER@$TARGET_IP"
echo ""

# Check if agent binary exists
if [[ ! -f "$AGENT_BINARY" ]]; then
    echo "Error: Yacht agent binary not found at $AGENT_BINARY"
    echo "Run 'just build' first to compile the agent."
    exit 1
fi

# Check for Nebula certificates
# We need the yacht's specific cert, named after the IP or hostname
YACHT_CERT="$NEBULA_DIR/yacht-$TARGET_IP.crt"
YACHT_KEY="$NEBULA_DIR/yacht-$TARGET_IP.key"
CA_CERT="$NEBULA_DIR/ca.crt"

if [[ ! -f "$CA_CERT" ]]; then
    echo "Error: Nebula CA certificate not found."
    echo "Run 'just gen-nebula-ca' first."
    exit 1
fi

if [[ ! -f "$YACHT_CERT" || ! -f "$YACHT_KEY" ]]; then
    echo "Warning: Yacht-specific certificate not found."
    echo "Expected: $YACHT_CERT"
    echo "Run: just gen-yacht-cert yacht-$TARGET_IP 192.168.100.X"
    echo ""
    echo "Continuing without Nebula certificates..."
fi

echo "--- Step 1: Testing SSH Connection ---"
if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$SSH_USER@$TARGET_IP" "echo 'SSH OK'" 2>/dev/null; then
    echo "Error: Cannot connect to $SSH_USER@$TARGET_IP"
    echo "Ensure SSH access is configured and the target is reachable."
    exit 1
fi
echo "SSH connection successful."
echo ""

echo "--- Step 2: Detecting Target OS ---"
TARGET_OS=$(ssh "$SSH_USER@$TARGET_IP" "cat /etc/os-release 2>/dev/null | grep '^ID=' | cut -d= -f2 | tr -d '\"'" || echo "unknown")
echo "Target OS: $TARGET_OS"
echo ""

echo "--- Step 3: Installing Dependencies ---"
case "$TARGET_OS" in
    fedora|coreos)
        echo "Installing on Fedora/CoreOS..."
        ssh "$SSH_USER@$TARGET_IP" "command -v podman || sudo dnf install -y podman"
        ;;
    debian|ubuntu)
        echo "Installing on Debian/Ubuntu..."
        ssh "$SSH_USER@$TARGET_IP" "command -v podman || sudo apt install -y podman"
        ;;
    alpine|wolfi)
        echo "Installing on Alpine/Wolfi..."
        ssh "$SSH_USER@$TARGET_IP" "command -v podman || sudo apk add podman"
        ;;
    *)
        echo "Warning: Unknown OS '$TARGET_OS'. Skipping dependency installation."
        ;;
esac
echo ""

echo "--- Step 4: Creating Directory Structure ---"
ssh "$SSH_USER@$TARGET_IP" "mkdir -p /opt/wharf/{bin,config,nebula}"
echo "Directories created."
echo ""

echo "--- Step 5: Uploading Yacht Agent ---"
scp "$AGENT_BINARY" "$SSH_USER@$TARGET_IP:/opt/wharf/bin/yacht-agent"
ssh "$SSH_USER@$TARGET_IP" "chmod +x /opt/wharf/bin/yacht-agent"
echo "Agent uploaded."
echo ""

echo "--- Step 6: Uploading Nebula Certificates ---"
if [[ -f "$CA_CERT" ]]; then
    scp "$CA_CERT" "$SSH_USER@$TARGET_IP:/opt/wharf/nebula/ca.crt"
fi
if [[ -f "$YACHT_CERT" ]]; then
    scp "$YACHT_CERT" "$SSH_USER@$TARGET_IP:/opt/wharf/nebula/host.crt"
    scp "$YACHT_KEY" "$SSH_USER@$TARGET_IP:/opt/wharf/nebula/host.key"
    ssh "$SSH_USER@$TARGET_IP" "chmod 600 /opt/wharf/nebula/host.key"
fi
echo "Certificates uploaded."
echo ""

echo "--- Step 7: Creating Systemd Service ---"
ssh "$SSH_USER@$TARGET_IP" "cat > /etc/systemd/system/yacht-agent.service << 'EOF'
[Unit]
Description=Wharf Yacht Agent
After=network.target

[Service]
Type=simple
ExecStart=/opt/wharf/bin/yacht-agent
Restart=always
RestartSec=5
User=root

# Security hardening
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes

[Install]
WantedBy=multi-user.target
EOF"

ssh "$SSH_USER@$TARGET_IP" "systemctl daemon-reload"
echo "Systemd service created."
echo ""

echo "--- Step 8: Starting Yacht Agent ---"
ssh "$SSH_USER@$TARGET_IP" "systemctl enable yacht-agent && systemctl start yacht-agent"
sleep 2

# Check status
if ssh "$SSH_USER@$TARGET_IP" "systemctl is-active yacht-agent" | grep -q "active"; then
    echo "Yacht Agent is running!"
else
    echo "Warning: Yacht Agent may not be running correctly."
    echo "Check with: ssh $SSH_USER@$TARGET_IP 'journalctl -u yacht-agent -n 50'"
fi
echo ""

echo "=== Deployment Complete ==="
echo ""
echo "The Yacht is now deployed at $TARGET_IP"
echo ""
echo "Next steps:"
echo "  1. Ensure Nebula mesh is configured for secure mooring"
echo "  2. Test connection: just moor $TARGET_IP"
echo "  3. Push your security policies: just push $TARGET_IP"
echo ""
echo "Admin API is available ONLY via Nebula mesh on port 9000."
echo "It is invisible to the public internet."
