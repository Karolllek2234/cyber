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

## Kibana

Open [http://localhost:5601](http://localhost:5601) after the stack is up. On first start, `elastic-setup` installs an ingest pipeline, index template, a data view named **nginx lab access logs** (`nginx-lab-*`), and three dashboards (from `shop/kibana/saved-objects.ndjson`):

| Dashboard | ID | What it shows |
|-----------|-----|----------------|
| **Request outcomes (success/failures)** | `lab-request-outcomes` | Successful vs failed responses; breakdown by `source.ip` |
| **Top target endpoints** | `lab-target-endpoints` | Top 15 paths with status breakdown (2xx / 4xx / other); paths by client IP |
| **Health and activity monitoring** | `lab-health-activity` | Request volume over time |

Direct links (after import):

- http://localhost:5601/app/dashboards#/view/lab-request-outcomes
- http://localhost:5601/app/dashboards#/view/lab-target-endpoints
- http://localhost:5601/app/dashboards#/view/lab-health-activity

Find them under **Analytics → Dashboard**. Set the time picker to include today’s `nginx-lab-*` index if panels look empty.

To refresh the saved dashboards after editing them in Kibana, export from **Stack Management → Saved Objects** (include related objects) or run:

```bash
./shop/setup/export-kibana-dashboards.sh
```

Then commit `shop/kibana/saved-objects.ndjson`.

## Error-rate email alerts

Staff notifications use [Mailpit](https://github.com/axllent/mailpit) as a local inbox. The `lab-alerter` service polls `nginx-lab-*` every minute and sends email when, in the last **5 minutes** (configurable):

- failed requests (HTTP ≥ 400) **exceed** successful requests (2xx/3xx), and
- failed count is at least **10** (configurable via `ALERT_MIN_FAILED`)

Open the inbox at [http://localhost:8025](http://localhost:8025). Alert emails link to the **Request outcomes** Kibana dashboard.

To test, generate attack traffic (many 4xx/5xx responses help trigger an alert sooner):

```bash
./simulation/scripts/run-juice-shop-attacks.sh
```

Tune sensitivity in `.env` — see [docker-env.md](docker-env.md).

In **Discover**, select that data view. Each nginx access line is parsed into structured fields:

| Field | Use |
|-------|-----|
| `http.request.method` | Filter by verb (`GET`, `POST`, …) |
| `url.path` | Filter by path (`/rest/products/search`, `/ftp/`, …) |
| `url.query` | Full query string (`q=test&foo=bar`) |
| `url.params.*` | Individual query parameters (e.g. `url.params.q` for search terms) |
| `http.response.status_code` | HTTP status |
| `source.ip` | Client IP |
| `user_agent.original` | User-Agent header |

Example KQL filters:

- `url.path : "/rest/products/search" and url.params.q : *union*`
- `http.request.method : "POST" and http.response.status_code >= 400`
- `url.path : "/ftp/*"`

Nginx writes one JSON object per line (`lab_json` format). Filebeat indexes into daily indices `nginx-lab-YYYY.MM.DD` via the `nginx-lab` ingest pipeline.

## Layout

- `shop/` — Juice Shop, nginx, Elasticsearch stack
- `simulation/` — user traffic + ZAP attacker
