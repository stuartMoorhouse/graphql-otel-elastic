#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TF_DIR="$PROJECT_ROOT/terraform"
ENV_FILE="$PROJECT_ROOT/shared/env.json"

# ── Prerequisites ────────────────────────────────────────────────────────────
if ! command -v terraform &> /dev/null; then
  echo "ERROR: terraform is not installed or not on PATH"
  exit 1
fi

if ! command -v jq &> /dev/null; then
  echo "ERROR: jq is not installed. Install with: sudo apt-get install jq (Ubuntu) or brew install jq (macOS)"
  exit 1
fi

# ── Read Terraform outputs ───────────────────────────────────────────────────
if [ ! -d "$TF_DIR" ]; then
  echo "ERROR: Terraform directory not found at $TF_DIR"
  exit 1
fi

cd "$TF_DIR"

if ! terraform output -raw vm_public_ip &> /dev/null; then
  echo "ERROR: Terraform outputs not available. Run 'terraform apply' first from $TF_DIR"
  exit 1
fi

VM_IP=$(terraform output -raw vm_public_ip)
GRAPHQL_URL=$(terraform output -raw graphql_url)
SSH_CMD=$(terraform output -raw ssh_command)

if [ -z "$VM_IP" ]; then
  echo "ERROR: vm_public_ip output is empty — VM may still be provisioning"
  exit 1
fi

# ── Write env.json (idempotent) ──────────────────────────────────────────────
mkdir -p "$PROJECT_ROOT/shared"

cat > "$ENV_FILE" <<EOF
{
  "vm_public_ip": "$VM_IP",
  "graphql_url": "$GRAPHQL_URL",
  "ssh_command": "$SSH_CMD"
}
EOF

# Validate the JSON we just wrote
if ! jq empty "$ENV_FILE" 2>/dev/null; then
  echo "ERROR: Failed to write valid JSON to $ENV_FILE"
  exit 1
fi

echo "Configuration written to $ENV_FILE"
echo "VM IP:          $VM_IP"
echo "GraphQL URL:    $GRAPHQL_URL"
echo "SSH command:    $SSH_CMD"
