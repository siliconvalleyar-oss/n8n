#!/usr/bin/env bash
# validate.sh — Validate all workflow JSON files
set -euo pipefail

WORKFLOW_DIR="${1:-./workflows}"
errors=0

echo "=== Validating workflows in $WORKFLOW_DIR ==="

for f in "$WORKFLOW_DIR"/*.json; do
    [ -f "$f" ] || continue
    name="$(basename "$f")"

    # Check it's valid JSON
    if jq empty "$f" 2>/dev/null; then
        echo "  ✓ $name"
    else
        echo "  ✗ $name — invalid JSON"
        errors=$((errors + 1))
        continue
    fi

    # Check required fields
    if ! jq -e '.nodes | length > 0' "$f" >/dev/null 2>&1; then
        echo "    ⚠  No nodes found"
    fi
    if ! jq -e '.name' "$f" >/dev/null 2>&1; then
        echo "    ⚠  Missing workflow name"
    fi
done

echo ""
if [ "$errors" -eq 0 ]; then
    echo "✓ All workflows valid"
else
    echo "✗ $errors invalid workflow(s) found"
fi

exit "$errors"
