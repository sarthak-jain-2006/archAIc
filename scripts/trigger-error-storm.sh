#!/usr/bin/env bash
set -euo pipefail

# Defaults assume local port-forwards on alternate ports.
AUTH_URL="${AUTH_URL:-http://127.0.0.1:8101}"
DB_URL="${DB_URL:-http://127.0.0.1:8102}"
PRODUCT_URL="${PRODUCT_URL:-http://127.0.0.1:8103}"
PAYMENT_URL="${PAYMENT_URL:-http://127.0.0.1:8104}"

DURATION="${DURATION:-120}"
REQUESTS="${REQUESTS:-500}"
CONCURRENCY="${CONCURRENCY:-50}"
PRE_RESET="${PRE_RESET:-1}"
TOKEN_RETRIES="${TOKEN_RETRIES:-5}"

log() {
  printf "[%s] %s\n" "$(date +"%H:%M:%S")" "$*"
}

reset_if_available() {
  local url="$1"
  curl -sS -X POST "$url/reset" >/dev/null || true
}

get_token_with_retries() {
  local login_json=""
  local token=""
  local i=1

  while [[ "$i" -le "$TOKEN_RETRIES" ]]; do
    login_json=$(curl -sS -X POST "$AUTH_URL/login" -H "Content-Type: application/json" -d "$BODY" || true)
    token=$(printf "%s" "$login_json" | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')

    if [[ -n "$token" ]]; then
      printf "%s" "$token"
      return 0
    fi

    log "Token fetch attempt ${i}/${TOKEN_RETRIES} failed; retrying..."
    sleep 1
    i=$((i + 1))
  done

  return 1
}

if [[ "$PRE_RESET" == "1" ]]; then
  log "Pre-resetting microservices to clear any prior injected failures"
  for u in "$AUTH_URL" "$DB_URL" "$PRODUCT_URL" "$PAYMENT_URL"; do
    reset_if_available "$u"
  done
fi

log "Preparing auth token for protected endpoints"
EMAIL="anom$(date +%s)@example.com"
PASS="secure123"
BODY=$(printf '{"email":"%s","password":"%s"}' "$EMAIL" "$PASS")

curl -sS -X POST "$AUTH_URL/signup" -H "Content-Type: application/json" -d "$BODY" >/dev/null || true
TOKEN=$(get_token_with_retries || true)

if [[ -z "$TOKEN" ]]; then
  echo "Failed to obtain auth token from $AUTH_URL/login after ${TOKEN_RETRIES} attempts"
  echo "Hint: verify port-forwards and run ./scripts/reset-all-microservices.sh"
  exit 1
fi

log "Injecting guaranteed 500 errors on auth, db, product, payment for ${DURATION}s"
for u in "$AUTH_URL" "$DB_URL" "$PRODUCT_URL" "$PAYMENT_URL"; do
  curl -fsS -X POST "$u/inject-failure?type=error&probability=1.0&duration=${DURATION}" >/dev/null &
done
wait

log "Sending concurrent traffic to produce 5xx spikes"
seq 1 "$REQUESTS" | xargs -I{} -P "$CONCURRENCY" sh -c 'curl -s -o /dev/null -w "%{http_code}\n" "'"$PRODUCT_URL"'/products" -H "Authorization: Bearer '"$TOKEN"'"' >/tmp/archaic_product_codes.txt
seq 1 "$REQUESTS" | xargs -I{} -P "$CONCURRENCY" sh -c 'curl -s -o /dev/null -w "%{http_code}\n" "'"$PRODUCT_URL"'/cart" -H "Authorization: Bearer '"$TOKEN"'"' >/tmp/archaic_cart_codes.txt
seq 1 "$REQUESTS" | xargs -I{} -P "$CONCURRENCY" sh -c 'curl -s -o /dev/null -w "%{http_code}\n" "'"$PAYMENT_URL"'/checkout" -H "Authorization: Bearer '"$TOKEN"'" -H "Content-Type: application/json" -d "{}"' >/tmp/archaic_payment_codes.txt || true

log "HTTP code summary (product /products):"
sort /tmp/archaic_product_codes.txt | uniq -c | sed 's/^/  /'

log "HTTP code summary (product /cart):"
sort /tmp/archaic_cart_codes.txt | uniq -c | sed 's/^/  /'

log "HTTP code summary (payment /checkout):"
sort /tmp/archaic_payment_codes.txt | uniq -c | sed 's/^/  /'

log "Error storm complete. If anomaly-detector is running, it should observe elevated 5xx metrics shortly."
log "Run ./scripts/reset-all-microservices.sh when done."
