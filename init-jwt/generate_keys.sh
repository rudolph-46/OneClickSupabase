#!/bin/sh
# ─────────────────────────────────────────────────────────────────────────────
# Supabase JWT Key Generator
# Runs once on first deploy. Generates ANON_KEY and SERVICE_ROLE_KEY
# from the shared JWT_SECRET using pure shell + openssl (no Node required).
#
# Railway injects JWT_SECRET via a shared variable. This script produces the
# two signed JWTs that all other Supabase services need.
# ─────────────────────────────────────────────────────────────────────────────

set -e

if [ -z "$JWT_SECRET" ]; then
  echo "ERROR: JWT_SECRET is not set. Cannot generate keys."
  exit 1
fi

# ── helpers ──────────────────────────────────────────────────────────────────

b64url() {
  # Base64-URL encode: standard base64, then swap chars and strip padding
  printf '%s' "$1" | openssl base64 -A | tr '+/' '-_' | tr -d '='
}

b64url_raw() {
  # Same but accepts stdin
  openssl base64 -A | tr '+/' '-_' | tr -d '='
}

sign_jwt() {
  ROLE="$1"
  ISSUED_AT=$(date +%s)
  # 10-year expiry — standard for Supabase anon/service keys
  EXPIRY=$((ISSUED_AT + 315360000))

  HEADER='{"alg":"HS256","typ":"JWT"}'
  PAYLOAD="{\"role\":\"${ROLE}\",\"iss\":\"supabase\",\"iat\":${ISSUED_AT},\"exp\":${EXPIRY}}"

  ENC_HEADER=$(b64url "$HEADER")
  ENC_PAYLOAD=$(b64url "$PAYLOAD")

  SIGNING_INPUT="${ENC_HEADER}.${ENC_PAYLOAD}"

  # HMAC-SHA256 sign, then base64url encode
  SIGNATURE=$(printf '%s' "$SIGNING_INPUT" \
    | openssl dgst -binary -sha256 -hmac "$JWT_SECRET" \
    | b64url_raw)

  echo "${SIGNING_INPUT}.${SIGNATURE}"
}

# ── generate ──────────────────────────────────────────────────────────────────

echo "Generating Supabase JWT keys..."

ANON_KEY=$(sign_jwt "anon")
SERVICE_ROLE_KEY=$(sign_jwt "service_role")

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Copy these values into your Railway Shared Variables:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "ANON_KEY=${ANON_KEY}"
echo ""
echo "SERVICE_ROLE_KEY=${SERVICE_ROLE_KEY}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Done. Both keys were derived from your JWT_SECRET."
echo "After pasting them into Railway, redeploy all services."
