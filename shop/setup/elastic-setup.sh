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

curl_json "Importing Kibana lab dashboards" \
  -X POST "${KB}/api/saved_objects/_import?overwrite=true" \
  -H "kbn-xsrf: true" \
  --form "file=@/setup/kibana/saved-objects.ndjson" \
  || exit 22

schedule_interval() {
  secs="${1:-60}"
  if [ "${secs}" -ge 60 ] && [ "$((secs % 60))" -eq 0 ]; then
    echo "$((secs / 60))m"
  else
    echo "${secs}s"
  fi
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

ALERT_STAFF_EMAIL="${ALERT_STAFF_EMAIL:-staff@lab.local}"
ALERT_WINDOW_MINUTES="${ALERT_WINDOW_MINUTES:-5}"
ALERT_MIN_FAILED="${ALERT_MIN_FAILED:-10}"
ALERT_CHECK_INTERVAL_SECONDS="${ALERT_CHECK_INTERVAL_SECONDS:-60}"
ALERT_COOLDOWN_MINUTES="${ALERT_COOLDOWN_MINUTES:-15}"
RULE_INTERVAL="$(schedule_interval "${ALERT_CHECK_INTERVAL_SECONDS}")"
RULE_THROTTLE="${ALERT_COOLDOWN_MINUTES}m"

ESQL="FROM nginx-lab-* | EVAL outcome = CASE(http.response.status_code >= 400, \"failed\", http.response.status_code >= 200 AND http.response.status_code < 400, \"success\", null) | WHERE outcome IS NOT NULL | STATS cnt = COUNT(*) BY outcome | EVAL success_cnt = CASE(outcome == \"success\", TO_DOUBLE(cnt), 0.0), failed_cnt = CASE(outcome == \"failed\", TO_DOUBLE(cnt), 0.0) | STATS success = SUM(success_cnt), failed = SUM(failed_cnt) | WHERE failed > success AND failed >= ${ALERT_MIN_FAILED}"
ESQL_JSON="$(json_escape "${ESQL}")"

rule_payload="$(cat <<EOF
{
  "name": "Lab nginx error rate exceeds success",
  "rule_type_id": ".es-query",
  "consumer": "stackAlerts",
  "enabled": true,
  "schedule": {
    "interval": "${RULE_INTERVAL}"
  },
  "params": {
    "searchType": "esqlQuery",
    "timeField": "@timestamp",
    "timeWindowSize": ${ALERT_WINDOW_MINUTES},
    "timeWindowUnit": "m",
    "size": 0,
    "excludeHitsFromPreviousRun": true,
    "thresholdComparator": ">",
    "threshold": [0],
    "esqlQuery": {
      "esql": "${ESQL_JSON}"
    }
  },
  "actions": [
    {
      "group": "query matched",
      "id": "lab-mailpit",
      "params": {
        "to": ["${ALERT_STAFF_EMAIL}"],
        "subject": "Lab alert: nginx error rate exceeds successes",
        "message": "Cyber lab nginx alert\\n\\n{{context.message}}\\n\\nConditions: {{context.conditions}}\\nValue: {{context.value}}\\nTime: {{context.date}}\\n\\nKibana dashboard: http://localhost:5601/app/dashboards#/view/lab-request-outcomes\\nMailpit inbox: http://localhost:8025\\n"
      },
      "frequency": {
        "summary": false,
        "notify_when": "onThrottleInterval",
        "throttle": "${RULE_THROTTLE}"
      }
    }
  ]
}
EOF
)"

RULE_ID="a0000000-0000-4000-8000-000000000001"
RULE_METHOD="POST"
RULE_URL="${KB}/api/alerting/rule/${RULE_ID}"
if curl -sf "${KB}/api/alerting/rule/${RULE_ID}" -H "kbn-xsrf: true" >/dev/null 2>&1; then
  RULE_METHOD="PUT"
fi

curl_json "Installing Kibana error-rate alert rule (${RULE_METHOD})" \
  -X "${RULE_METHOD}" "${RULE_URL}" \
  -H "Content-Type: application/json" \
  -H "kbn-xsrf: true" \
  -d "${rule_payload}" \
  || exit 22

echo "Elastic stack setup complete"
