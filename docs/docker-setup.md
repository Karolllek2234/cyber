# Docker setup

From the project root:

```bash
cp .env.example .env   # optional
docker compose up -d --build
```

Artifacts: `simulation/outputs/` (e.g. `zap-report.html`)

Environment variables are documented in [docker-env.md](docker-env.md).

## Layout

- `shop/` — Juice Shop, nginx, Elasticsearch stack
- `simulation/` — user traffic + ZAP attacker
