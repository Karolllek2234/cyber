#!/bin/sh
set -eu

ES="${ELASTICSEARCH_HOST:-http://elasticsearch:9200}"
WINDOW="${ALERT_WINDOW_MINUTES:-5}"
MIN_FAILED="${ALERT_MIN_FAILED:-10}"

response="$(curl -sf "${ES}/nginx-lab-*/_search" \
  -H "Content-Type: application/json" \
  -d "{
    \"size\": 0,
    \"query\": { \"range\": { \"@timestamp\": { \"gte\": \"now-${WINDOW}m\" } } },
    \"aggs\": {
      \"success\": { \"filter\": { \"range\": { \"http.response.status_code\": { \"gte\": 200, \"lt\": 400 } } } },
      \"failed\": { \"filter\": { \"range\": { \"http.response.status_code\": { \"gte\": 400 } } } }
    }
  }")"

success="$(printf '%s' "${response}" | jq -r '.aggregations.success.doc_count // 0')"
failed="$(printf '%s' "${response}" | jq -r '.aggregations.failed.doc_count // 0')"

export ALERT_SUCCESS_COUNT="${success}"
export ALERT_FAILED_COUNT="${failed}"

printf 'ALERT_SUCCESS_COUNT=%s\nALERT_FAILED_COUNT=%s\n' "${success}" "${failed}" > /tmp/alert-counts

if [ "${failed}" -ge "${MIN_FAILED}" ] && [ "${failed}" -gt "${success}" ]; then
  exit 0
fi

exit 1
