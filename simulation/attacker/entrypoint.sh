#!/usr/bin/env bash
set -euo pipefail

ZAP_PORT="${ZAP_PORT:-8080}"
ATTACKER_START_DELAY_SECONDS="${ATTACKER_START_DELAY_SECONDS:-60}"

if [ "${ATTACKER_START_DELAY_SECONDS}" -gt 0 ]; then
  echo "Waiting ${ATTACKER_START_DELAY_SECONDS}s for user traffic before starting ZAP..."
  sleep "${ATTACKER_START_DELAY_SECONDS}"
fi

echo "Starting ZAP daemon on port ${ZAP_PORT}..."
/zap/zap.sh -daemon \
  -host 0.0.0.0 \
  -port "${ZAP_PORT}" \
  -config api.disablekey=true \
  -config api.addrs.addr.name=.* \
  -config api.addrs.addr.regex=true \
  -config database.recoverylog=false

echo "Waiting for ZAP API..."
for _ in $(seq 1 60); do
  if curl -sf "http://127.0.0.1:${ZAP_PORT}/JSON/core/view/version/" >/dev/null; then
    echo "ZAP is ready."
    break
  fi
  sleep 2
done

if ! curl -sf "http://127.0.0.1:${ZAP_PORT}/JSON/core/view/version/" >/dev/null; then
  echo "ZAP failed to start within the expected time." >&2
  exit 1
fi

exec tail -f /dev/null
