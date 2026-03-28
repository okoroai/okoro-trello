#!/usr/bin/env bash
# trello.sh — Trello API via Okoro proxy with token session caching.
#
# Usage:
#   ./trello.sh --endpoint <path> --intent <text> [--method GET] [--scope read] [--payload <json>]
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

if [[ -z "${OKORO_SERVICE_TOKEN:-}" ]]; then
  echo "" >&2
  echo "Error: OKORO_SERVICE_TOKEN is not set." >&2
  echo "" >&2
  echo "  This skill requires an Okoro service token to authenticate with Trello." >&2
  echo "  Get your token at: https://hub.okoro.ai/docs/get-token" >&2
  echo "" >&2
  echo "  Once you have it, set it in your environment:" >&2
  echo "    export OKORO_SERVICE_TOKEN=svc_..." >&2
  echo "" >&2
  exit 1
fi

# Infer scope from method if not explicitly set
if [[ "$SCOPE" == "read" ]]; then
  case "$METHOD" in
    POST)        SCOPE="write"  ;;
    PUT|PATCH)   SCOPE="update" ;;
    DELETE)      SCOPE="delete" ;;
  esac
fi

# ── Curl helper — returns body on stdout; exits with error on non-2xx ────────
_curl() {
  local tmpfile
  tmpfile=$(mktemp)
  local http_code
  http_code=$(curl -s -o "$tmpfile" -w "%{http_code}" "$@") || {
    rm -f "$tmpfile"
    echo "Error: curl failed (network error)" >&2
    exit 1
  }
  local body
  body=$(cat "$tmpfile")
  rm -f "$tmpfile"

  if [[ "$http_code" -lt 200 || "$http_code" -ge 300 ]]; then
    echo "Error: HTTP $http_code" >&2
    local err_msg
    # Handle nested error objects (e.g. {"error":{"code":403,"message":"..."}})
    # and flat errors (e.g. {"error":"...","message":"..."})
    err_msg=$(printf '%s' "$body" | jq -r '
      if .error | type == "object" then (.error.message // (.error | tostring))
      else (.error // .message) | strings
      end
    ' 2>/dev/null || true)
    if [[ -n "$err_msg" ]]; then
      echo "  $err_msg" >&2
    elif [[ -n "$body" ]]; then
      echo "  ${body:0:300}" >&2
    fi
    exit 1
  fi

  printf '%s' "$body"
}

# ── Token caching ──────────────────────────────────────────────────────────
_token_prefix="${OKORO_SERVICE_TOKEN:4:8}"
TOKEN_CACHE="${TMPDIR:-/tmp}/okoro_trello_${_token_prefix}_${SCOPE}.tok"

_jwt_exp() {
  local payload="${1%%.*}"
  payload="${1#*.}"
  payload="${payload%%.*}"
  local rem=$(( ${#payload} % 4 ))
  [[ $rem -eq 2 ]] && payload="${payload}=="
  [[ $rem -eq 3 ]] && payload="${payload}="
  printf '%s' "$payload" | tr '_-' '/+' | base64 -d 2>/dev/null | jq -r '.exp // 0' 2>/dev/null || echo 0
}

_fetch_token() {
  local refresh_token="${1:-}"
  local body
  body=$(jq -n \
    --arg provider "trello" \
    --arg scope    "$SCOPE" \
    --arg intent   "$INTENT" \
    '{provider: $provider, scope: $scope, intent: $intent}')
  [[ -n "$refresh_token" ]] && \
    body=$(printf '%s' "$body" | jq --arg t "$refresh_token" '. + {refresh_token: $t}')

  local response token exp
  response=$(_curl -X POST "https://okoro.ai/t/tokens" \
    -H "Authorization: Bearer ${OKORO_SERVICE_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$body")
  token=$(printf '%s' "$response" | jq -r '.token // empty')
  [[ -z "$token" ]] && { echo "Error: token missing from response" >&2; exit 1; }
  exp=$(_jwt_exp "$token")
  printf '%s\n%s' "$token" "$exp" > "$TOKEN_CACHE"
  printf '%s' "$token"
}

TOKEN=""
_expired_token=""
if [[ -f "$TOKEN_CACHE" ]]; then
  _cached_token=$(sed -n '1p' "$TOKEN_CACHE")
  _cached_exp=$(sed -n '2p' "$TOKEN_CACHE")
  _now=$(date +%s)
  if [[ -n "$_cached_token" && "$_cached_exp" -gt $(( _now + 60 )) ]]; then
    TOKEN="$_cached_token"
  else
    _expired_token="$_cached_token"
  fi
fi

[[ -z "$TOKEN" ]] && TOKEN=$(_fetch_token "$_expired_token")

# ── Make the request ───────────────────────────────────────────────────────
PROXY_URL="https://okoro.ai/p/trello${ENDPOINT}"

if [[ -n "$PAYLOAD" && "$METHOD" =~ ^(GET|HEAD)$ ]]; then
  echo "Error: --payload cannot be used with $METHOD requests. Pass query parameters in --endpoint instead." >&2
  exit 1
fi

if [[ -n "$PAYLOAD" ]]; then
  _curl -X "$METHOD" "$PROXY_URL" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD"
else
  _curl -X "$METHOD" "$PROXY_URL" \
    -H "Authorization: Bearer ${TOKEN}"
fi
