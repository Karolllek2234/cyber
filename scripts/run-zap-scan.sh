#!/usr/bin/env bash
# Run from the project root after: docker compose up -d
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if ! docker compose exec -T attacker true 2>/dev/null; then
  echo "The attacker container is not running. Start the stack first:" >&2
  echo "  docker compose up -d" >&2
  exit 1
fi

chmod +x "${ROOT_DIR}/scripts/zap-scan.sh"
docker compose exec -T attacker /scripts/zap-scan.sh "$@"

REPORT_HOST="${ROOT_DIR}/zap-reports/zap-report.html"
if [[ -f "${REPORT_HOST}" ]]; then
  echo "Host report path: ${REPORT_HOST}"
fi
