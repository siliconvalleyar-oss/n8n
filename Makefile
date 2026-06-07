.PHONY: up down restart logs ps status shell backup clean setup validate

# ─── Lifecycle ───────────────────────────────────────────────────────────────

up:
	docker compose --env-file .env up -d

down:
	docker compose down

restart: down up

logs:
	docker compose logs -f n8n

ps:
	docker compose ps

status:
	@echo "=== n8n ===" && curl -s -o /dev/null -w "%{http_code}" http://localhost:${N8N_PORT:-5678}/healthz || echo "offline"
	@echo ""
	@echo "=== Redis ===" && docker compose exec redis redis-cli ping

# ─── Shell Access ────────────────────────────────────────────────────────────

shell-n8n:
	docker compose exec n8n sh

shell-redis:
	docker compose exec redis redis-cli

shell-ffmpeg:
	docker compose exec ffmpeg-worker sh

# ─── Workflow Management ─────────────────────────────────────────────────────

import:
	@echo "Importing workflows from ./workflows/*.json..."
	@for f in workflows/*.json; do \
		echo "  → $$f"; \
		curl -s -X POST "http://localhost:${N8N_PORT:-5678}/rest/workflows" \
			-H "Content-Type: application/json" \
			-d @$$f; \
	done

export:
	@mkdir -p exports
	@echo "Exporting all workflows to ./exports/..."
	@curl -s "http://localhost:${N8N_PORT:-5678}/rest/workflows" \
		| jq -c '.data[]' \
		| while read wf; do \
			name=$$(echo $$wf | jq -r '.name' | tr ' ' '_'); \
			echo $$wf > "exports/$$name.json"; \
		done

# ─── Storage ─────────────────────────────────────────────────────────────────

storage-dirs:
	mkdir -p storage/videos storage/assets storage/output

backup:
	@mkdir -p backups
	@echo "Backing up n8n data..."
	docker compose exec n8n sh -c "cp /home/node/.n8n/database.sqlite /tmp/backup.sqlite"
	docker compose cp n8n:/tmp/backup.sqlite backups/n8n_$$(date +%Y%m%d_%H%M%S).sqlite
	@echo "Backup saved to backups/"

# ─── Development ─────────────────────────────────────────────────────────────

validate:
	@echo "Validating workflow JSONs..."
	@for f in workflows/*.json; do \
		echo -n "  $$f: "; \
		jq empty "$$f" 2>&1 && echo "✓" || echo "✗"; \
	done

clean:
	docker compose down -v
	rm -rf storage/* exports/* backups/*

# ─── Help ────────────────────────────────────────────────────────────────────

help:
	@echo "Targets:"
	@echo "  up            Start all services (docker compose up -d)"
	@echo "  down          Stop all services"
	@echo "  restart       Restart all services"
	@echo "  logs          Follow n8n logs"
	@echo "  ps            Show container status"
	@echo "  status        Quick health check"
	@echo "  shell-n8n     Open shell in n8n container"
	@echo "  shell-redis   Open redis-cli"
	@echo "  shell-ffmpeg  Open shell in ffmpeg container"
	@echo "  import        Import workflows from ./workflows/"
	@echo "  export        Export workflows to ./exports/"
	@echo "  storage-dirs  Create storage directories"
	@echo "  backup        Backup n8n SQLite database"
	@echo "  validate      Validate workflow JSON files"
	@echo "  clean         Remove all data (volumes + storage)"
