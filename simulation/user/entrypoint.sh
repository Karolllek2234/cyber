#!/bin/sh
set -eu

TARGET_URL="${TARGET_URL:-http://nginx:8080/}"
INTERVAL="${USER_REQUEST_INTERVAL_SECONDS:-5}"
SIMULATED_TRAFFIC_USER="${SIMULATED_TRAFFIC_USER:-0}"
USER_AGENT="${USER_AGENT:-Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36}"

BASE="${TARGET_URL%/}"

PATHS="
/
/api/Products
/api/Challenges
/api/Quantitys
/rest/admin/application-configuration
"

echo "Waiting for ${BASE}..."
until curl -sf -A "${USER_AGENT}" -o /dev/null "${BASE}/"; do
  sleep 2
done

if [ "${SIMULATED_TRAFFIC_USER}" -gt 0 ]; then
  echo "Delaying user traffic for ${SIMULATED_TRAFFIC_USER}s (SIMULATED_TRAFFIC_USER)..."
  sleep "${SIMULATED_TRAFFIC_USER}"
fi

echo "Browsing ${BASE} every ${INTERVAL}s..."
while true; do
  for path in ${PATHS}; do
    curl -sf -A "${USER_AGENT}" -o /dev/null "${BASE}${path}" || true
  done
  sleep "${INTERVAL}"
done
