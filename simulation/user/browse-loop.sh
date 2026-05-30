#!/bin/sh
set -eu

TARGET_URL="${TARGET_URL:-http://nginx:8080/}"
INTERVAL="${USER_REQUEST_INTERVAL_SECONDS:-5}"
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

echo "Browsing ${BASE} every ${INTERVAL}s..."
while true; do
  for path in ${PATHS}; do
    curl -sf -A "${USER_AGENT}" -o /dev/null "${BASE}${path}" || true
  done
  sleep "${INTERVAL}"
done
