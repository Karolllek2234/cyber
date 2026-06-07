#!/bin/sh
set -eu

INTERVAL="${ALERT_CHECK_INTERVAL_SECONDS:-60}"
COOLDOWN_MINUTES="${ALERT_COOLDOWN_MINUTES:-15}"
COOLDOWN_FILE="/tmp/last-alert-sent"
ES="${ELASTICSEARCH_HOST:-http://elasticsearch:9200}"

wait_for_es() {
  i=0
  while [ "$i" -lt 60 ]; do
    if curl -sf "${ES}" >/dev/null 2>&1; then
      echo "Elasticsearch is ready"
      return 0
    fi
    i=$((i + 1))
    sleep 2
  done
  echo "Elasticsearch did not become ready in time" >&2
  exit 1
}

cooldown_active() {
  if [ ! -f "${COOLDOWN_FILE}" ]; then
    return 1
  fi

  last_sent="$(cat "${COOLDOWN_FILE}")"
  now="$(date +%s)"
  elapsed=$((now - last_sent))
  cooldown_seconds=$((COOLDOWN_MINUTES * 60))

  if [ "${elapsed}" -lt "${cooldown_seconds}" ]; then
    return 0
  fi

  return 1
}

wait_for_es
echo "Lab alerter running (interval=${INTERVAL}s, window=${ALERT_WINDOW_MINUTES:-5}m, min_failed=${ALERT_MIN_FAILED:-10})"

while true; do
  if /alerter/check-error-rate.sh; then
    # shellcheck disable=SC1091
    . /tmp/alert-counts
    export ALERT_SUCCESS_COUNT ALERT_FAILED_COUNT
    if cooldown_active; then
      echo "Alert condition met but cooldown active (success=${ALERT_SUCCESS_COUNT}, failed=${ALERT_FAILED_COUNT})"
    else
      /alerter/send-alert-email.sh
      date +%s > "${COOLDOWN_FILE}"
    fi
  fi
  sleep "${INTERVAL}"
done
