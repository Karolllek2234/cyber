# Docker setup

From the project root:

```bash
docker compose up -d --build
./scripts/run-zap-scan.sh
```

Report: `zap-reports/zap-report.html`

Optional env (in `docker-compose.yml` or `.env`):

- `USER_REQUEST_INTERVAL_SECONDS` — pause between browse loops (default `5`)
- `ATTACKER_START_DELAY_SECONDS` — wait after `user` starts before ZAP daemon (default `60`)
