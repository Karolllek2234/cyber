# Docker setup

From the project root:

```bash
cp .env.example .env   # optional
docker compose up -d --build
```

Report: `simulation/zap-reports/zap-report.html`

## Scan trigger

| `SIMULATED_TRAFFIC_TRIGGER` | Behaviour |
|-----------------------------|-----------|
| `false` (default) | Run the scan manually: `./simulation/scripts/run-zap-scan.sh` |
| `true` | Scan runs automatically when ZAP is ready |

## Simulation timing

| Variable | Default | Meaning |
|----------|---------|---------|
| `SIMULATED_TRAFFIC_USER` | `0` | Seconds to wait after the shop is up before user browsing starts |
| `SIMULATED_TRAFFIC_ATTACKER` | `60` | Seconds to wait before the ZAP daemon starts |
| `USER_REQUEST_INTERVAL_SECONDS` | `5` | Pause between user browse loops |

## Layout

- `shop/` — Juice Shop, nginx, Elasticsearch stack
- `simulation/` — user traffic + ZAP attacker

## Ports

- `SHOP_HTTP_PORT` — nginx listen + host publish port (default `8080`)
