#!/usr/bin/env bash
set -euo pipefail

# Trello API wrapper
# Usage: trello.sh <METHOD> <path> [key=value ...]
#
# Values are automatically URL-encoded — pass them as plain text.
#
# Examples:
#   trello.sh GET /members/me
#   trello.sh GET /boards/abc123/lists
#   trello.sh POST /cards name=My Task idList=abc123
#   trello.sh PUT /cards/abc123 "name=Q&A Session"
#   trello.sh DELETE /cards/abc123
#   trello.sh POST /cards/abc123/attachments file=@/path/to/doc.pdf

BASE_URL="https://api.trello.com/1"

# --- Validate environment ---

if [[ -z "${TRELLO_API_KEY:-}" ]]; then
  echo "Error: TRELLO_API_KEY is not set" >&2
  exit 1
fi

if [[ -z "${TRELLO_TOKEN:-}" ]]; then
  echo "Error: TRELLO_TOKEN is not set" >&2
  exit 1
fi

# --- Parse arguments ---

if [[ $# -lt 2 ]]; then
  echo "Usage: trello.sh <METHOD> <path> [key=value ...]" >&2
  echo "  METHOD   GET, POST, PUT, DELETE" >&2
  echo "  path     API path, e.g. /boards/{id}" >&2
  echo "  params   Query params as key=value pairs" >&2
  exit 1
fi

METHOD=$(echo "$1" | tr '[:lower:]' '[:upper:]')
shift

API_PATH="$1"
shift

# --- URL-encode helper (python3 stdlib — battle-tested, handles all Unicode) ---

urlencode() {
  python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.stdin.read(), safe=''), end='')" <<< "$1"
}

# --- Build curl arguments ---

TMPFILE=$(mktemp /tmp/trello-XXXXXX.json)
trap 'rm -f "$TMPFILE"' EXIT

CURL_ARGS=(-s -o "$TMPFILE" -w "%{http_code}" -X "$METHOD")

# Separate file upload params (-F) from query params
QUERY_PARAMS=()
FILE_PARAMS=()

for param in "$@"; do
  if [[ "$param" == *"=@"* ]]; then
    FILE_PARAMS+=("$param")
  else
    QUERY_PARAMS+=("$param")
  fi
done

# Build query string: auth + URL-encoded user params
QUERY="key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
for param in "${QUERY_PARAMS[@]+"${QUERY_PARAMS[@]}"}"; do
  KEY="${param%%=*}"
  VALUE="${param#*=}"
  QUERY="${QUERY}&${KEY}=$(urlencode "$VALUE")"
done

URL="${BASE_URL}${API_PATH}?${QUERY}"

# Add file upload flags
for fparam in "${FILE_PARAMS[@]+"${FILE_PARAMS[@]}"}"; do
  # Split key=@path into -F "key=@path"
  CURL_ARGS+=(-F "$fparam")
done

# --- Execute ---

HTTP_CODE=$(curl "${CURL_ARGS[@]}" "$URL")

if [[ "$HTTP_CODE" -ge 400 ]]; then
  echo "Error: HTTP ${HTTP_CODE}" >&2
  jq . "$TMPFILE" 2>/dev/null >&2 || cat "$TMPFILE" >&2
  exit 1
fi

# Output response — try jq for pretty JSON, fall back to raw
jq . "$TMPFILE" 2>/dev/null || cat "$TMPFILE"
