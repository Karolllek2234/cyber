# Docker setup

From the project root:

```bash
docker compose up -d --build
./simulation/scripts/run-zap-scan.sh
```

Report: `simulation/zap-reports/zap-report.html`

Layout:

- `shop/` — Juice Shop, nginx, Elasticsearch stack
- `simulation/` — user traffic + ZAP attacker

Copy `.env.example` to `.env` to override ports (optional):

```bash
cp .env.example .env
```

- `SHOP_HTTP_PORT` — nginx listen + host publish port (default `8080`; use a port ≥ 1024 for rootless/userspace Docker)
