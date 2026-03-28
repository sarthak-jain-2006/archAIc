#!/usr/bin/env bash
set -euo pipefail

# Defaults assume local port-forwards on alternate ports.
AUTH_URL="${AUTH_URL:-http://127.0.0.1:8101}"
DB_URL="${DB_URL:-http://127.0.0.1:8102}"
PRODUCT_URL="${PRODUCT_URL:-http://127.0.0.1:8103}"
PAYMENT_URL="${PAYMENT_URL:-http://127.0.0.1:8104}"

log() {
  printf "[%s] %s\n" "$(date +"%H:%M:%S")" "$*"
}

reset_one() {
  local name="$1"
  local url="$2"
  if curl -fsS -X POST "$url/reset" >/dev/null; then
    log "reset ok: $name ($url/reset)"
  else
    log "reset failed: $name ($url/reset)"
  fi
}

log "Resetting failure state for auth, db, product, and payment"
reset_one "auth" "$AUTH_URL"
reset_one "db" "$DB_URL"
reset_one "product" "$PRODUCT_URL"
reset_one "payment" "$PAYMENT_URL"

log "Done. Note: ai-operator and anomaly-detector currently do not expose /reset endpoints."
