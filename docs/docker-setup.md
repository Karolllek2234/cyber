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

Open [http://localhost:5601](http://localhost:5601) after the stack is up. On first start, `elastic-setup` installs an ingest pipeline, index template, and a data view named **nginx lab access logs** (`nginx-lab-*`).

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
