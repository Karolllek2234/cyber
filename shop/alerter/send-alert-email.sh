#!/bin/sh
set -eu

MAILPIT="${MAILPIT_HTTP_URL:-http://mailpit:8025}"
FROM="${ALERT_FROM_EMAIL:-alerts@cyber.lab}"
TO="${ALERT_STAFF_EMAIL:-staff@lab.local}"
WINDOW="${ALERT_WINDOW_MINUTES:-5}"
KIBANA_URL="${KIBANA_PUBLIC_URL:-http://localhost:5601}"

success="${ALERT_SUCCESS_COUNT:-0}"
failed="${ALERT_FAILED_COUNT:-0}"
timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

subject="Lab alert: failed requests (${failed}) exceed successes (${success})"
body="Cyber lab nginx alert

Time (UTC): ${timestamp}
Window: last ${WINDOW} minutes

Successful requests (2xx/3xx): ${success}
Failed requests (4xx/5xx):     ${failed}

Condition: failed > success and failed >= ${ALERT_MIN_FAILED:-10}

Review in Kibana:
${KIBANA_URL}/app/dashboards#/view/lab-request-outcomes

Mailpit inbox: http://localhost:8025
"

payload="$(jq -n \
  --arg from "${FROM}" \
  --arg to "${TO}" \
  --arg subject "${subject}" \
  --arg text "${body}" \
  '{
    From: {Name: "Lab Alerts", Email: $from},
    To: [{Email: $to}],
    Subject: $subject,
    Text: $text
  }')"

curl -sf -X POST "${MAILPIT}/api/v1/send" \
  -H "Content-Type: application/json" \
  -d "${payload}" >/dev/null

echo "Alert email sent to ${TO} (success=${success}, failed=${failed})"
