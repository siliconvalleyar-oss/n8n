#!/usr/bin/env bash
# deploy.sh — Deploy workflow files to a running n8n instance
set -euo pipefail

N8N_URL="${N8N_URL:-http://localhost:5678}"
API_KEY="${N8N_API_KEY:-}"
WORKFLOW_DIR="${1:-./workflows}"

echo "=== Deploying workflows from $WORKFLOW_DIR ==="
echo "Target: $N8N_URL"

for f in "$WORKFLOW_DIR"/*.json; do
    [ -f "$f" ] || continue
    name="$(basename "$f" .json)"
    echo -n "  → $name ... "

    # Validate JSON
    jq empty "$f" 2>/dev/null || { echo "INVALID JSON"; continue; }

    # Inject name from filename into JSON
    payload=$(jq --arg n "$name" '.name = $n' "$f")

    # POST or fail
    if [ -n "$API_KEY" ]; then
        code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$N8N_URL/rest/workflows" \
            -H "Content-Type: application/json" \
            -H "X-N8N-API-KEY: $API_KEY" \
            -d "$payload")
    else
        code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$N8N_URL/rest/workflows" \
            -H "Content-Type: application/json" \
            -d "$payload")
    fi

    case "$code" in
        200|201) echo "OK" ;;
        401)     echo "AUTH ERROR - set N8N_API_KEY"; exit 1 ;;
        *)       echo "HTTP $code";;
    esac
done

echo "=== Done ==="
