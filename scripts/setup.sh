#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

echo "=== n8n TikTok Video Editor - Setup ==="

# --- Prerequisites ---
echo ""
echo "[1/5] Checking prerequisites..."

command -v docker >/dev/null 2>&1 || { echo "ERROR: docker is required"; exit 1; }
command -v jq    >/dev/null 2>&1 || { echo "WARN: jq not found (optional for workflow validation)"; }

# --- .env ---
echo "[2/5] Configuring environment..."
if [ ! -f .env ]; then
    if [ -f .env.example ]; then
        cp .env.example .env
        echo "  Created .env from .env.example"
        echo "  ⚠ EDIT .env and set your N8N_ENCRYPTION_KEY before running"
    fi
else
    echo "  .env already exists"
fi

# --- Storage ---
echo "[3/5] Creating storage directories..."
mkdir -p storage/videos storage/assets storage/output
echo "  ✓ storage/videos"
echo "  ✓ storage/assets"
echo "  ✓ storage/output"

# --- Docker Compose ---
echo "[4/5] Starting services..."
if docker compose --env-file .env up -d 2>/dev/null; then
    echo "  ✓ n8n started on http://localhost:${N8N_PORT:-5678}"
else
    echo "  ERROR: docker compose failed"
    echo "  Try: docker compose --env-file .env up -d"
    exit 1
fi

# --- Validate ---
echo "[5/5] Validating setup..."
sleep 5
if curl -sf "http://localhost:${N8N_PORT:-5678}/healthz" >/dev/null 2>&1; then
    echo "  ✓ n8n is healthy"
else
    echo "  ⚠ n8n health check failed — check logs: make logs"
fi

echo ""
echo "=== Setup complete ==="
echo "  n8n UI:     http://localhost:${N8N_PORT:-5678}"
echo "  Storage:    ./storage/{videos,assets,output}"
echo "  Workflows:  ./workflows/*.json"
echo ""
echo "Next steps:"
echo "  1. Import workflows: make import"
echo "  2. Or manually import via n8n UI → Workflows → Add → Import from File"
echo "  3. Edit .env to configure API keys and sources"
