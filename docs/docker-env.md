# Docker environment variables

Set in a project-root `.env` file (copy from [`.env.example`](../.env.example)). Compose reads these when you run `docker compose up`.

## Host configuration

| Variable | Default | Used by | Description |
|----------|---------|---------|-------------|
| `SHOP_HTTP_PORT` | `8080` | `nginx` | Nginx listen port inside the container and on the host. Use ≥ 1024 for rootless Docker. |
| `USER_REQUEST_INTERVAL_SECONDS` | `5` | `user` | Pause between simulated user browse loops. |
| `SIMULATED_TRAFFIC_USER` | `0` | `user` | Seconds to wait after the shop is reachable before browsing starts. |
| `SIMULATED_TRAFFIC_ATTACKER` | `60` | `attacker` | Seconds to wait before the ZAP daemon starts. |
| `SIMULATED_TRAFFIC_ATTACKER_DELAY` | `60` | `attacker` | Seconds to wait after ZAP is ready before an automatic scan runs. Only applies when `SIMULATED_TRAFFIC_TRIGGER=true`. |
| `SIMULATED_TRAFFIC_TRIGGER` | `false` | `attacker` | `true` — run the ZAP scan automatically after the delay above. `false` — trigger manually with `./simulation/scripts/run-zap-scan.sh`. |
| `ALERT_STAFF_EMAIL` | `staff@lab.local` | `elastic-setup` | Recipient address for error-rate alert emails (captured by Mailpit). |
| `ALERT_FROM_EMAIL` | `alerts@cyber.lab` | `kibana` | From address on the preconfigured Mailpit email connector (`shop/kibana/kibana.yml`). |
| `ALERT_WINDOW_MINUTES` | `5` | `elastic-setup` | Rolling window for comparing failed vs successful requests in the Kibana ES\|QL rule. |
| `ALERT_MIN_FAILED` | `10` | `elastic-setup` | Minimum failed requests required before an alert can fire. |
| `ALERT_CHECK_INTERVAL_SECONDS` | `60` | `elastic-setup` | Kibana rule check interval (converted to e.g. `1m`). |
| `ALERT_COOLDOWN_MINUTES` | `15` | `elastic-setup` | Minimum time between alert emails (`onThrottleInterval` on the rule action). |

## Set by compose (not in `.env`)

| Variable | Value | Used by | Description |
|----------|-------|---------|-------------|
| `TARGET_URL` | `http://nginx:<SHOP_HTTP_PORT>/` | `user`, `attacker` | Scan and browse target; derived from `SHOP_HTTP_PORT`. |
| `ZAP_PORT` | `8080` | `attacker` | ZAP API port inside the attacker container. |

## Optional overrides

Not wired in compose by default. Add under `environment:` in [`simulation/docker-compose.yml`](../simulation/docker-compose.yml) to override.

| Variable | Default | Script | Description |
|----------|---------|--------|-------------|
| `USER_AGENT` | Chrome 120 UA string | `user` (`browse-loop.sh`) | HTTP User-Agent for simulated browsing. |
| `REPORT_DIR` | `/outputs` | `attacker` (`zap-scan.sh`) | Directory for the HTML report inside the container. |
| `REPORT_FILE` | `<REPORT_DIR>/zap-report.html` | `attacker` (`zap-scan.sh`) | Full path to the ZAP HTML report. |

## Startup timeline

When `SIMULATED_TRAFFIC_TRIGGER=true`:

```
shop up → SIMULATED_TRAFFIC_USER → user browsing
       → SIMULATED_TRAFFIC_ATTACKER → ZAP daemon
       → SIMULATED_TRAFFIC_ATTACKER_DELAY → automatic scan
```
