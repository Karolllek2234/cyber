# Docker setup

From the project root:

```bash
cp .env.example .env   # optional
docker compose up -d --build
```

Artifacts: `simulation/outputs/` (e.g. `zap-report.html`)

Environment variables are documented in [docker-env.md](docker-env.md).

## Scripted attacks

Run SQL injection, XSS, and directory traversal against Juice Shop through nginx (executed in the `attacker` container):

```bash
./simulation/scripts/run-juice-shop-attacks.sh
```

Traffic is logged by nginx and shipped to Elasticsearch via Filebeat.

## Layout

- `shop/` — Juice Shop, nginx, Elasticsearch stack
- `simulation/` — user traffic + ZAP attacker
