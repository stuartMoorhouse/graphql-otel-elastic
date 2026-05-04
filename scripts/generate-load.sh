#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/shared/env.json"

# ── Defaults ─────────────────────────────────────────────────────────────────
COUNT=10
DELAY=0.5

# ── Argument parsing ─────────────────────────────────────────────────────────
usage() {
  echo "Usage: $0 [--count N] [--delay SECONDS]"
  echo ""
  echo "  --count N        Number of load iterations (default: 10)"
  echo "  --delay SECONDS  Delay between requests in seconds (default: 0.5)"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --count)
      COUNT="${2:-}"
      if [ -z "$COUNT" ]; then echo "ERROR: --count requires a value"; usage; fi
      shift 2
      ;;
    --delay)
      DELAY="${2:-}"
      if [ -z "$DELAY" ]; then echo "ERROR: --delay requires a value"; usage; fi
      shift 2
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
if ! command -v curl &> /dev/null; then
  echo "ERROR: curl is not installed"
  exit 1
fi

if ! command -v jq &> /dev/null; then
  echo "ERROR: jq is not installed. Install with: sudo apt-get install jq (Ubuntu) or brew install jq (macOS)"
  exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: $ENV_FILE not found. Run scripts/configure.sh first."
  exit 1
fi

GRAPHQL_URL=$(jq -r '.graphql_url' "$ENV_FILE")

if [ -z "$GRAPHQL_URL" ] || [ "$GRAPHQL_URL" = "null" ]; then
  echo "ERROR: graphql_url is empty in $ENV_FILE. Re-run scripts/configure.sh."
  exit 1
fi

# ── Helper: send a GraphQL request ───────────────────────────────────────────
# Returns HTTP status code. Prints response body to stderr for debugging on failure.
graphql_request() {
  local label="$1"
  local payload="$2"

  local http_status
  local response_body

  response_body=$(curl \
    --silent \
    --show-error \
    --max-time 10 \
    --write-out "\n%{http_code}" \
    --header "Content-Type: application/json" \
    --data "$payload" \
    "$GRAPHQL_URL" 2>&1) || {
    echo "  [WARN] $label — connection refused or network error (is the VM up?)"
    return 0
  }

  http_status=$(echo "$response_body" | tail -n1)
  local body
  body=$(echo "$response_body" | sed '$d')

  if [ "$http_status" = "200" ]; then
    # Check for GraphQL-level errors in the response body
    local errors
    errors=$(echo "$body" | jq -r '.errors // empty' 2>/dev/null || true)
    if [ -n "$errors" ]; then
      echo "  [WARN] $label — HTTP 200 but GraphQL errors: $errors"
    else
      echo "  [OK]   $label"
    fi
  else
    echo "  [WARN] $label — unexpected HTTP status $http_status"
  fi
}

# ── Queries and mutations ─────────────────────────────────────────────────────
query_posts() {
  graphql_request "posts (list)" \
    '{"query":"{ posts { id title author { name } createdAt } }"}'
}

query_post_with_detail() {
  local id=$((RANDOM % 5 + 1))
  graphql_request "post(id: $id) with author+comments" \
    "{\"query\":\"{ post(id: \\\"$id\\\") { id title content author { id name email } comments { id body author { name } } } }\"}"
}

query_authors() {
  graphql_request "authors (list)" \
    '{"query":"{ authors { id name email posts { id title } } }"}'
}

mutation_create_post() {
  local title="Load test post $RANDOM at $(date +%s)"
  local content="Auto-generated content $RANDOM — OTel trace test run."
  graphql_request "createPost mutation" \
    "{\"query\":\"mutation { createPost(title: \\\"$title\\\", content: \\\"$content\\\", authorId: \\\"1\\\") { id title } }\"}"
}

mutation_create_comment() {
  local post_id=$((RANDOM % 5 + 1))
  local body="Test comment $RANDOM on post $post_id"
  graphql_request "createComment mutation (post $post_id)" \
    "{\"query\":\"mutation { createComment(postId: \\\"$post_id\\\", body: \\\"$body\\\", authorId: \\\"1\\\") { id body } }\"}"
}

# ── Main loop ─────────────────────────────────────────────────────────────────
echo "Generating GraphQL load against: $GRAPHQL_URL"
echo "Iterations: $COUNT, delay: ${DELAY}s between requests"
echo ""

for i in $(seq 1 "$COUNT"); do
  echo "--- Iteration $i / $COUNT ---"

  query_posts
  sleep "$DELAY"

  query_post_with_detail
  sleep "$DELAY"

  query_authors
  sleep "$DELAY"

  mutation_create_post
  sleep "$DELAY"

  mutation_create_comment

  if [ "$i" -lt "$COUNT" ]; then
    sleep "$DELAY"
  fi
done

echo ""
echo "Load generation complete. Check Elastic APM for traces."
echo "  Service: graphql-blog"
echo "  Kibana: look for traces in Observability -> APM -> Services"
