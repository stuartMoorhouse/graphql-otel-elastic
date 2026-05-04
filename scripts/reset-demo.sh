#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/shared/env.json"

# ── Defaults ──────────────────────────────────────────────────────────────────
WARMUP=false

# ── Argument parsing ──────────────────────────────────────────────────────────
usage() {
  echo "Usage: $0 [--warmup]"
  echo ""
  echo "  --warmup   After restarting the service, run generate-load.sh to warm up traces"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --warmup)
      WARMUP=true
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "ERROR: Unknown argument: $1"
      usage
      ;;
  esac
done

# ── Prerequisites ─────────────────────────────────────────────────────────────
if ! command -v jq &> /dev/null; then
  echo "ERROR: jq is not installed. Install with: sudo apt-get install jq (Ubuntu) or brew install jq (macOS)"
  exit 1
fi

if ! command -v ssh &> /dev/null; then
  echo "ERROR: ssh is not available"
  exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: $ENV_FILE not found. Run scripts/configure.sh first."
  exit 1
fi

VM_IP=$(jq -r '.vm_public_ip' "$ENV_FILE")
SSH_CMD=$(jq -r '.ssh_command' "$ENV_FILE")
GRAPHQL_URL=$(jq -r '.graphql_url' "$ENV_FILE")

if [ -z "$VM_IP" ] || [ "$VM_IP" = "null" ]; then
  echo "ERROR: vm_public_ip is empty in $ENV_FILE. Re-run scripts/configure.sh."
  exit 1
fi

# Extract username from ssh_command (format: "ssh <user>@<host>")
SSH_USER=$(echo "$SSH_CMD" | awk '{print $2}' | cut -d@ -f1)

echo "Resetting demo on VM: $VM_IP (user: $SSH_USER)"
echo ""

# ── Step 1: Restart the graphql-blog service ──────────────────────────────────
echo "==> Restarting graphql-blog service..."
ssh -o StrictHostKeyChecking=no \
    -o ConnectTimeout=15 \
    -o BatchMode=yes \
    "${SSH_USER}@${VM_IP}" \
    "sudo systemctl restart graphql-blog && sudo systemctl status graphql-blog --no-pager --lines=10" || {
  echo "ERROR: Failed to connect to VM at $VM_IP"
  echo "  Verify the VM is running and your SSH key is available."
  echo "  SSH command from env.json: $SSH_CMD"
  exit 1
}

echo ""
echo "==> Service restarted. Waiting 5s for the process to come up..."
sleep 5

# ── Step 2: Verify the GraphQL endpoint responds ──────────────────────────────
echo "==> Verifying GraphQL endpoint ($GRAPHQL_URL)..."
HTTP_STATUS=$(curl --silent --max-time 10 --output /dev/null --write-out "%{http_code}" \
  --header "Content-Type: application/json" \
  --data '{"query":"{ __typename }"}' \
  "$GRAPHQL_URL" 2>/dev/null || echo "000")

if [ "$HTTP_STATUS" = "200" ]; then
  echo "    GraphQL endpoint is responding (HTTP 200)."
else
  echo "    WARNING: GraphQL endpoint returned HTTP $HTTP_STATUS — service may still be starting."
  echo "    Check logs on the VM with: $SSH_CMD"
  echo "    Then run: sudo journalctl -u graphql-blog -n 50"
fi

echo ""

# ── Step 3: APM data reminder ────────────────────────────────────────────────
echo "==> APM data reset (manual step required)"
echo ""
echo "    OTel data in Elastic APM is NOT automatically cleared."
echo "    To reset APM data for a clean demo, delete the service in Kibana:"
echo ""
echo "    1. Open Kibana -> Observability -> APM -> Services"
echo "    2. Click on 'graphql-blog'"
echo "    3. Use the service settings or Index Management to clear old data"
echo "       (exact steps depend on your Kibana version)"
echo ""
echo "    Alternatively, use the Kibana Dev Tools console to delete APM indices:"
echo "    DELETE /traces-apm-*"
echo "    DELETE /metrics-apm-*"
echo ""
echo "    Note: Deletion affects ALL services in this Elastic project —"
echo "    only do this on a dedicated demo environment."
echo ""

# ── Step 4: Optional warmup ───────────────────────────────────────────────────
if [ "$WARMUP" = "true" ]; then
  LOAD_SCRIPT="$SCRIPT_DIR/generate-load.sh"
  if [ ! -f "$LOAD_SCRIPT" ]; then
    echo "ERROR: generate-load.sh not found at $LOAD_SCRIPT"
    exit 1
  fi
  echo "==> Running generate-load.sh to warm up traces..."
  bash "$LOAD_SCRIPT" --count 5 --delay 0.3
  echo ""
fi

echo "==> Reset complete."
echo "    GraphQL URL: $GRAPHQL_URL"
