#!/bin/sh
set -eu

ES="${ELASTICSEARCH_HOST:-http://elasticsearch:9200}"
KB="${KIBANA_HOST:-http://kibana:5601}"

wait_for() {
  url="$1"
  name="$2"
  i=0
  while [ "$i" -lt 60 ]; do
    if curl -sf "$url" >/dev/null 2>&1; then
      echo "${name} is ready"
      return 0
    fi
    i=$((i + 1))
    sleep 2
  done
  echo "${name} did not become ready in time" >&2
  exit 1
}

curl_json() {
  label="$1"
  shift

  echo "${label}..."
  response="$(mktemp)"
  http_code="$(curl -sS -o "${response}" -w '%{http_code}' "$@")"
  if [ "${http_code}" -ge 400 ]; then
    echo "${label} failed (HTTP ${http_code}):" >&2
    cat "${response}" >&2
    echo >&2
    rm -f "${response}"
    return 1
  fi

  rm -f "${response}"
  return 0
}

wait_for "${ES}" "Elasticsearch"
wait_for "${KB}/api/status" "Kibana"

curl_json "Installing ingest pipeline nginx-lab" \
  -X PUT "${ES}/_ingest/pipeline/nginx-lab" \
  -H "Content-Type: application/json" \
  --data-binary "@/setup/ingest-pipeline.json" \
  || exit 22

curl_json "Installing index template nginx-lab" \
  -X PUT "${ES}/_index_template/nginx-lab" \
  -H "Content-Type: application/json" \
  --data-binary "@/setup/index-template.json" \
  || exit 22

if curl -sf "${KB}/api/data_views/data_view/nginx-lab-data-view" \
  -H "kbn-xsrf: true" >/dev/null 2>&1; then
  echo "Kibana data view already exists"
else
  i=0
  while [ "$i" -lt 12 ]; do
    if curl_json "Creating Kibana data view (attempt $((i + 1))/12)" \
      -X POST "${KB}/api/data_views/data_view" \
      -H "Content-Type: application/json" \
      -H "kbn-xsrf: true" \
      -d '{
        "data_view": {
          "id": "nginx-lab-data-view",
          "title": "nginx-lab-*",
          "name": "nginx lab access logs",
          "timeFieldName": "@timestamp",
          "allowNoIndex": true
        }
      }'; then
      break
    fi
    i=$((i + 1))
    if [ "$i" -lt 12 ]; then
      sleep 5
    fi
  done

  if [ "$i" -eq 12 ]; then
    echo "Failed to create Kibana data view after 12 attempts" >&2
    exit 22
  fi
fi

echo "Elastic stack setup complete"
