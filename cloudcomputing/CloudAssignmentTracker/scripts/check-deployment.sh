#!/usr/bin/env bash
# End-to-end check of the deployed app: create, read, update and delete an assignment
# Usage: bash scripts/check-deployment.sh [frontend-public-ip]

set -uo pipefail

TARGET="${1:-}"
if [ -z "$TARGET" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  TARGET="$(terraform -chdir="$SCRIPT_DIR/../terraform" output -raw frontend_public_ip 2>/dev/null || true)"
fi
if [ -z "$TARGET" ]; then
  echo "Usage: bash $0 <frontend-public-ip-or-url>"
  exit 2
fi

case "$TARGET" in
  http*) BASE="${TARGET%/}" ;;
  *)     BASE="http://$TARGET" ;;
esac
API="$BASE/api/assignments"

PASSED=0
FAILED=0
CREATED_ID=""

pass() { echo "PASS  $1"; PASSED=$((PASSED + 1)); }
fail() { echo "FAIL  $1"; FAILED=$((FAILED + 1)); }

# request METHOD URL [JSON_BODY]  ->  sets STATUS and RESPONSE
request() {
  local method="$1" url="$2" data="${3:-}" out
  if [ -n "$data" ]; then
    out=$(curl -s --max-time 15 -w $'\n%{http_code}' -X "$method" \
      -H "Content-Type: application/json" -d "$data" "$url")
  else
    out=$(curl -s --max-time 15 -w $'\n%{http_code}' -X "$method" "$url")
  fi
  STATUS="${out##*$'\n'}"
  RESPONSE="${out%$'\n'*}"
}

summary() {
  echo
  echo "$PASSED passed, $FAILED failed"
  if [ "$FAILED" -eq 0 ]; then echo "RESULT: PASS"; else echo "RESULT: FAIL"; fi
}

# Remove the test assignment if the script stops before deleting it
cleanup() {
  if [ -n "$CREATED_ID" ]; then
    curl -s --max-time 15 -o /dev/null -X DELETE "$API/$CREATED_ID"
  fi
}
trap cleanup EXIT

TITLE="Automated check $(date +%s)"
echo "Checking $BASE"
echo

# 1. Frontend page is served by Nginx
request GET "$BASE/"
if [ "$STATUS" = "200" ] && grep -q "Assignment Tracker" <<<"$RESPONSE"; then
  pass "Frontend page loads"
else
  fail "Frontend page loads (HTTP $STATUS)"
fi

# 2. Backend is reachable through the Nginx /api/ proxy
request GET "$API"
if [ "$STATUS" = "200" ]; then
  pass "Backend API reachable through frontend proxy"
else
  fail "Backend API reachable through frontend proxy (HTTP $STATUS)"
  echo "      Backend is not responding; skipping the remaining checks."
  summary
  exit 1
fi

# 3. Create an assignment (write to RDS)
request POST "$API" "{\"title\":\"$TITLE\",\"description\":\"Created by check-deployment.sh\",\"dueDate\":\"2030-01-01\"}"
CREATED_ID=$(sed -n 's/.*"id":\([0-9][0-9]*\).*/\1/p' <<<"$RESPONSE")
if [ "$STATUS" = "200" ] && [ -n "$CREATED_ID" ]; then
  pass "Create assignment (write to RDS) -> id $CREATED_ID"
else
  fail "Create assignment (HTTP $STATUS)"
  summary
  exit 1
fi

# 4. Read it back by id (read from RDS)
request GET "$API/$CREATED_ID"
if [ "$STATUS" = "200" ] && grep -q "$TITLE" <<<"$RESPONSE"; then
  pass "Read assignment back by id (read from RDS)"
else
  fail "Read assignment back by id (HTTP $STATUS)"
fi

# 5. It appears in the full list
request GET "$API"
if grep -q "$TITLE" <<<"$RESPONSE"; then
  pass "Assignment appears in list"
else
  fail "Assignment appears in list"
fi

# 6. Update its status
request PUT "$API/$CREATED_ID" "{\"title\":\"$TITLE\",\"description\":\"Created by check-deployment.sh\",\"dueDate\":\"2030-01-01\",\"status\":\"COMPLETED\"}"
if [ "$STATUS" = "200" ] && grep -q '"status":"COMPLETED"' <<<"$RESPONSE"; then
  pass "Update assignment status"
else
  fail "Update assignment status (HTTP $STATUS)"
fi

# 7. The update was saved
request GET "$API/$CREATED_ID"
if grep -q '"status":"COMPLETED"' <<<"$RESPONSE"; then
  pass "Update persisted in RDS"
else
  fail "Update persisted in RDS"
fi

# 8. Delete it
request DELETE "$API/$CREATED_ID"
if [ "$STATUS" = "204" ]; then
  pass "Delete assignment"
else
  fail "Delete assignment (HTTP $STATUS)"
fi

# 9. It is really gone :)
request GET "$API/$CREATED_ID"
if [ "$STATUS" = "404" ]; then
  pass "Deleted assignment no longer exists"
  CREATED_ID=""
else
  fail "Deleted assignment no longer exists (HTTP $STATUS)"
fi

summary
[ "$FAILED" -eq 0 ]
