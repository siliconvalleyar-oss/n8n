# n8n TikTok Video Editor

Sistema modular y escalable de edición de video automatizada para TikTok usando n8n + FFmpeg.

## Arquitectura

```
                        ┌─────────────────┐
                        │  Trend Analytics │ ◄── Schedule (cada 6h)
                        └────────┬────────┘
                                 │ temas virales
                                 ▼
┌────────────┐    ┌─────────────────────────┐    ┌──────────────────┐
│ Content     │──►│  TikTok Orchestrator    │──►│  Publisher        │
│ Ingestion   │   │  (workflow principal)   │   │  (local/tiktok)   │
├────────────┤   ├─────────────────────────┤   ├──────────────────┤
│ • RSS      │   │  Valida payload         │   │ • Guardar local   │
│ • Reddit   │   │  Descarga videos        │   │ • API TikTok      │
│ • YouTube  │   │  Enruta por estilo      │   │ • Slack/Discord   │
│ • Webhook  │   │  Llama sub-workflows    │   │ • Reportes        │
└────────────┘   └────────┬────────────────┘   └──────────────────┘
                          │
                          ▼
           ┌──────────────────────────────┐
           │     Video Processor          │
           │     (sub-workflow FFmpeg)    │
           ├──────────────────────────────┤
           │ 1. Resize a 9:16 (1080x1920) │
           │ 2. Trim a duración TikTok    │
           │ 3. Speed (opcional)          │
           │ 4. Background music mix      │
           │ 5. Captions (AI o script)    │
           │ 6. Watermark overlay         │
           │ 7. Cleanup temp files        │
           └──────────────────────────────┘
                          │
                          ▼
           ┌──────────────────────────────┐
           │     Caption Generator        │
           │     (sub-workflow)           │
           ├──────────────────────────────┤
           │ • AI: Whisper (auto-SRT)     │
           │ • Script: texto → SRT        │
           │ • FFmpeg subtitles burn-in   │
           └──────────────────────────────┘
```

## Estructura del Proyecto

```
n8n/
├── docker-compose.yml        # Stack completo (n8n + Redis + FFmpeg)
├── .env.example              # Template de configuración
├── Makefile                  # Comandos de gestión
├── config/
│   └── settings.json         # Configuración global de video
├── scripts/
│   ├── setup.sh              # Setup inicial
│   ├── deploy.sh             # Deploy workflows a n8n
│   ├── validate.sh           # Validar JSONs
│   └── ffmpeg/
│       └── tiktok-preset.sh  # Preset TikTok FFmpeg
├── workflows/
│   ├── tiktok-orchestrator.json   # Orquestador principal (ID: 1)
│   ├── video-processor.json       # Pipeline FFmpeg (ID: 2)
│   ├── caption-generator.json     # Subtítulos AI/script (ID: 3)
│   ├── content-ingestion.json     # Fuentes de contenido
│   ├── asset-manager.json         # Download/cleanup assets
│   ├── trend-analytics.json       # Escaneo de tendencias
│   ├── publisher.json             # Publicación y notificaciones
│   └── error-handler.json         # Manejo de errores
└── storage/
    ├── videos/     # Videos raw descargados
    ├── assets/     # Música, watermarks, thumbnails
    └── output/     # Videos terminados
```

## Quick Start

```bash
# 1. Configurar
cp .env.example .env
# Editar .env - cambiar N8N_ENCRYPTION_KEY y ajustar paths

# 2. Iniciar servicios
make up
# o: bash scripts/setup.sh

# 3. Verificar
make status

# 4. Importar workflows (desde n8n UI o CLI)
make import
```

## Workflows

| # | Workflow | Trigger | Propósito |
|---|----------|---------|-----------|
| 1 | **TikTok Orchestrator** | Schedule / Webhook / Manual | Orquesta el pipeline completo |
| 2 | **Video Processor** | Sub-workflow | Pipeline FFmpeg 7 pasos |
| 3 | **Caption Generator** | Sub-workflow | Subtítulos (Whisper AI o script) |
| 4 | **Content Ingestion** | RSS / Reddit / YouTube / Webhook | Obtener contenido de fuentes |
| 5 | **Asset Manager** | Sub-workflow | Download, list, cleanup assets |
| 6 | **Trend Analytics** | Schedule (cada 6h) | Escanear hashtags virales |
| 7 | **Publisher** | Sub-workflow | Guardar + notificar |
| 8 | **Error Handler** | Sub-workflow | Logging + cleanup |

## Pipeline de Video (7 pasos)

El `video-processor` ejecuta esta secuencia FFmpeg:

1. **Resize** → 1080x1920 9:16 con padding negro
2. **Trim** → Corta a duración objetivo (15-60s)
3. **Speed** → Ajuste de velocidad opcional
4. **BGM** → Mezcla audio original + música de fondo
5. **Captions** → Quema subtítulos (SRT)
6. **Watermark** → Overlay de logo
7. **Cleanup** → Elimina archivos temporales

## Escalabilidad

- **Sub-workflows**: Cada skill es un workflow independiente, invocable desde el orquestador
- **Modular**: Añadir nuevo skill = crear workflow + conectar al orquestador
- **Estilos**: Soporta `standard`, `educational`, `funny`, `asmr` (cada uno con parámetros distintos)
- **Colas**: Redis listo para modo queue de n8n
- **Config**: Centralizada en `.env` + `config/settings.json`

## Comandos Make

```bash
make up           # Iniciar servicios
make down         # Parar servicios
make logs         # Logs de n8n
make status       # Health check
make import       # Importar workflows
make export       # Exportar workflows
make backup       # Backup DB
make validate     # Validar JSONs
make shell-n8n    # Shell en contenedor n8n
make shell-ffmpeg # Shell en contenedor FFmpeg
```

## API Webhooks

- `POST /webhook/tiktok-pipeline` → Inicia pipeline con payload JSON
- `POST /webhook/ingest-video` → Ingestion directa

### Payload de Ejemplo

```json
{
  "videoUrl": "https://example.com/video.mp4",
  "script": "Texto para subtítulos...",
  "style": "educational",
  "targetDuration": 45,
  "includeCaptions": true,
  "includeWatermark": true,
  "backgroundMusic": "trending"
}
```

## Requisitos

- Docker + Docker Compose
- FFmpeg (incluido en contenedor `jrottenberg/ffmpeg`)
- n8n (incluido en `docker-compose.yml`)
- Opcional: Whisper (para captioning AI), cuentas de API (Reddit, YouTube, TikTok)
