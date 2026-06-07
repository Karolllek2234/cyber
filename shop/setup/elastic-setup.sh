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

wait_for "${ES}" "Elasticsearch"
wait_for "${KB}/api/status" "Kibana"

echo "Installing ingest pipeline nginx-lab..."
curl -sf -X PUT "${ES}/_ingest/pipeline/nginx-lab" \
  -H "Content-Type: application/json" \
  --data-binary "@/setup/ingest-pipeline.json"

echo "Installing index template nginx-lab..."
curl -sf -X PUT "${ES}/_index_template/nginx-lab" \
  -H "Content-Type: application/json" \
  --data-binary "@/setup/index-template.json"

echo "Creating Kibana data view nginx lab access logs..."
if curl -sf "${KB}/api/data_views/data_view/nginx-lab-data-view" \
  -H "kbn-xsrf: true" >/dev/null 2>&1; then
  echo "Kibana data view already exists"
else
  curl -sf -X POST "${KB}/api/data_views/data_view" \
    -H "Content-Type: application/json" \
    -H "kbn-xsrf: true" \
    -d '{
      "data_view": {
        "id": "nginx-lab-data-view",
        "title": "nginx-lab-*",
        "name": "nginx lab access logs",
        "timeFieldName": "@timestamp"
      }
    }'
fi

echo "Elastic stack setup complete"
