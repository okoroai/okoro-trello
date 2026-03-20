#!/usr/bin/env bash
# trello.sh — Trello API via Okoro proxy with token session caching.
#
# Usage:
#   ./trello.sh --endpoint <path> --intent <text> [--method GET] [--scope read] [--payload <json>]
#
# Examples:
#   ./trello.sh --endpoint /members/me/boards --intent "list all boards"
#   ./trello.sh --endpoint /cards --method POST --scope write \
#               --intent "create task" --payload '{"idList":"...","name":"..."}'
#   ./trello.sh --endpoint /cards/<id> --method DELETE --scope delete --intent "remove card"
#
# Required env:
#   OKORO_SERVICE_TOKEN   Service token from the okoro dashboard (svc_...)
set -euo pipefail

ENDPOINT=""
METHOD="GET"
SCOPE="read"
PAYLOAD=""
INTENT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --endpoint) ENDPOINT="${2:?--endpoint requires a value}"; shift 2 ;;
    --method)   METHOD="${2:?--method requires a value}";     shift 2 ;;
    --scope)    SCOPE="${2:?--scope requires a value}";       shift 2 ;;
    --payload)  PAYLOAD="${2:?--payload requires a value}";   shift 2 ;;
    --intent)   INTENT="${2:?--intent requires a value}";     shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$ENDPOINT" ]] && { echo "Error: --endpoint is required" >&2; exit 1; }
[[ -z "$INTENT"   ]] && { echo "Error: --intent is required" >&2; exit 1; }

# Infer scope from method if not explicitly set
if [[ "$SCOPE" == "read" ]]; then
  case "$METHOD" in
    POST)   SCOPE="write"  ;;
    PUT)    SCOPE="update" ;;
    DELETE) SCOPE="delete" ;;
  esac
fi

# ── Token caching ──────────────────────────────────────────────────────────
# Cache per service token prefix + scope so different workspaces don't collide.
_token_prefix="${OKORO_SERVICE_TOKEN:4:8}"
TOKEN_CACHE="${TMPDIR:-/tmp}/okoro_trello_${_token_prefix}_${SCOPE}.tok"

_jwt_exp() {
  # Decode the payload segment of a JWT and extract .exp
  local payload="${1%%.*}"       # strip header (first dot and beyond)
  payload="${1#*.}"              # remove header
  payload="${payload%%.*}"       # remove signature
  local rem=$(( ${#payload} % 4 ))
  [[ $rem -eq 2 ]] && payload="${payload}=="
  [[ $rem -eq 3 ]] && payload="${payload}="
  printf '%s' "$payload" | tr '_-' '/+' | base64 -d 2>/dev/null | jq -r '.exp // 0' 2>/dev/null || echo 0
}

_fetch_token() {
  local response token exp
  response=$(curl -sf -X POST "https://okoro.ai/t/tokens" \
    -H "Authorization: Bearer ${OKORO_SERVICE_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"provider\":\"trello\",\"scope\":\"${SCOPE}\",\"intent\":$(printf '%s' "${INTENT}" | jq -Rs .)}")
  token=$(printf '%s' "$response" | jq -r '.token // empty')
  [[ -z "$token" ]] && { echo "Error: failed to obtain token" >&2; exit 1; }
  exp=$(_jwt_exp "$token")
  printf '%s\n%s' "$token" "$exp" > "$TOKEN_CACHE"
  printf '%s' "$token"
}

TOKEN=""
if [[ -f "$TOKEN_CACHE" ]]; then
  _cached_token=$(sed -n '1p' "$TOKEN_CACHE")
  _cached_exp=$(sed -n '2p' "$TOKEN_CACHE")
  _now=$(date +%s)
  # Reuse if token has more than 60 seconds remaining
  if [[ -n "$_cached_token" && "$_cached_exp" -gt $(( _now + 60 )) ]]; then
    TOKEN="$_cached_token"
  fi
fi

[[ -z "$TOKEN" ]] && TOKEN=$(_fetch_token)

# ── Make the request ───────────────────────────────────────────────────────
PROXY_URL="https://okoro.ai/p/trello${ENDPOINT}"

if [[ -n "$PAYLOAD" ]]; then
  curl -sf -X "$METHOD" "$PROXY_URL" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD"
else
  curl -sf -X "$METHOD" "$PROXY_URL" \
    -H "Authorization: Bearer ${TOKEN}"
fi
