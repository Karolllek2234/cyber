#!/bin/sh
set -eu

KB="${KIBANA_HOST:-http://localhost:5601}"
OUT="${1:-shop/kibana/saved-objects.ndjson}"

if ! curl -sf "${KB}/api/status" -H "kbn-xsrf: true" >/dev/null 2>&1; then
  echo "Kibana is not reachable at ${KB}" >&2
  exit 1
fi

dashboard_ids="lab-request-outcomes lab-target-endpoints lab-health-activity"
objects=""
for id in ${dashboard_ids}; do
  if curl -sf "${KB}/api/saved_objects/dashboard/${id}" -H "kbn-xsrf: true" >/dev/null 2>&1; then
    objects="${objects}{\"type\":\"dashboard\",\"id\":\"${id}\"},"
  else
    echo "Warning: dashboard ${id} not found, skipping" >&2
  fi
done

if [ -z "${objects}" ]; then
  echo "No lab dashboards found in Kibana" >&2
  exit 1
fi

objects="${objects%,}"
tmp="$(mktemp)"
trap 'rm -f "${tmp}"' EXIT

curl -sf -X POST "${KB}/api/saved_objects/_export" \
  -H "Content-Type: application/json" \
  -H "kbn-xsrf: true" \
  -d "{\"objects\":[${objects}],\"includeReferencesDeep\":true,\"excludeExportDetails\":true}" \
  > "${tmp}"

python3 - "${tmp}" "${OUT}" <<'PY'
import json
import sys

src, dst = sys.argv[1], sys.argv[2]
rows = []
for line in open(src):
    line = line.strip()
    if not line:
        continue
    obj = json.loads(line)
    if obj.get("type") == "index-pattern":
        continue
    rows.append(obj)

order = {"lens": 0, "visualization": 1, "dashboard": 2}
rows.sort(key=lambda o: (order.get(o.get("type"), 9), o.get("attributes", {}).get("title", "")))

with open(dst, "w") as out:
    for obj in rows:
        out.write(json.dumps(obj, separators=(",", ":")) + "\n")

from collections import Counter
counts = Counter(o["type"] for o in rows)
print(f"Wrote {dst}")
for typ, count in sorted(counts.items()):
    print(f"  {typ}: {count}")
PY
