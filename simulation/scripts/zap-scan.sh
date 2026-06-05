#!/usr/bin/env bash
# Runs inside the attacker container against an already-running ZAP daemon.
set -euo pipefail

ZAP_PORT="${ZAP_PORT:-8080}"
TARGET_URL="${TARGET_URL:-http://nginx:8080/}"
REPORT_DIR="${REPORT_DIR:-/outputs}"
REPORT_FILE="${REPORT_FILE:-${REPORT_DIR}/zap-report.html}"

wait_for_zap() {
  echo "Waiting for ZAP API on port ${ZAP_PORT}..."
  for _ in $(seq 1 60); do
    if zap-cli -p "${ZAP_PORT}" status 2>/dev/null | grep -qi "running"; then
      return 0
    fi
    sleep 2
  done
  echo "ZAP is not reachable on port ${ZAP_PORT}." >&2
  exit 1
}

wait_for_zap

echo "Target: ${TARGET_URL}"
echo "Opening URL..."
zap-cli -p "${ZAP_PORT}" open-url "${TARGET_URL}"

echo "Spidering..."
zap-cli -p "${ZAP_PORT}" spider "${TARGET_URL}"

echo "Active scan (recursive)..."
zap-cli -p "${ZAP_PORT}" active-scan --recursive "${TARGET_URL}"

echo "Alerts (Low and above):"
zap-cli -p "${ZAP_PORT}" alerts -l Low || true

mkdir -p "${REPORT_DIR}"
echo "Writing HTML report to ${REPORT_FILE}..."
zap-cli -p "${ZAP_PORT}" report -o "${REPORT_FILE}" -f html

echo "Scan complete. Report: ${REPORT_FILE}"
