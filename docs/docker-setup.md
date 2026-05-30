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

Optional env (in `simulation/docker-compose.yml` or `.env`):

- `USER_REQUEST_INTERVAL_SECONDS` — pause between browse loops (default `5`)
- `ATTACKER_START_DELAY_SECONDS` — wait after `user` starts before ZAP daemon (default `60`)
