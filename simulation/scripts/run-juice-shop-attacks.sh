#!/usr/bin/env bash
# Run from the project root after the stack is up.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

if ! docker compose exec -T attacker true 2>/dev/null; then
  echo "The attacker container is not running. Start the stack first:" >&2
  echo "  docker compose up -d" >&2
  exit 1
fi

chmod +x "${ROOT_DIR}/simulation/scripts/juice-shop-attacks.sh"
docker compose exec -T attacker /scripts/juice-shop-attacks.sh "$@"
