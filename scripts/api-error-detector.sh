#!/usr/bin/env bash
set -euo pipefail

# PostToolUse hook: detect Trello API errors and suggest recovery actions.
# Reads JSON from stdin (Claude Code PostToolUse format), checks if the
# command invoked a Trello plugin script, inspects the response for HTTP
# errors, and outputs actionable suggestions as additionalContext.
#
# NOTE: trello.sh writes "Error: HTTP {code}" and the response body to
# both stdout and stderr on failures (via tee). Claude Code's Bash
# tool_response captures this output, so these patterns should match.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

if [[ -z "$COMMAND" ]]; then
  exit 0
fi

# Only act on commands that invoke trello plugin scripts
if [[ "$COMMAND" != *"/scripts/trello.sh"* && "$COMMAND" != *"/scripts/spec-manager.sh"* ]]; then
  exit 0
fi

RESPONSE=$(echo "$INPUT" | jq -r '.tool_response // ""')

if [[ -z "$RESPONSE" ]]; then
  exit 0
fi

# Normalise the response to lowercase for case-insensitive matching
RESPONSE_LOWER=$(echo "$RESPONSE" | tr '[:upper:]' '[:lower:]')

suggest() {
  local msg="$1"
  jq -n --arg ctx "$msg" \
    '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":$ctx}}'
  exit 0
}

# HTTP 404 — endpoint not found, likely stale spec
if echo "$RESPONSE" | grep -qE '(HTTP[/ ][0-9.]+[[:space:]]+404|HTTP error.*404|"status":\s*404|404 Not Found)'; then
  suggest "Trello API returned HTTP 404. The endpoint may have changed. Run: spec-manager.sh update-spec to refresh the cached OpenAPI spec, then re-query for the correct endpoint path."
fi

# HTTP 401/403 — authentication or authorisation failure
if echo "$RESPONSE" | grep -qE '(HTTP[/ ][0-9.]+[[:space:]]+(401|403)|HTTP error.*(401|403)|"status":\s*(401|403)|401 Unauthorized|403 Forbidden|unauthorized permission|invalid (app)?key|invalid token)'; then
  suggest "Trello API returned an authentication/authorisation error. Check that TRELLO_API_KEY and TRELLO_TOKEN are set correctly in your shell profile and have not expired. Re-generate credentials at https://trello.com/power-ups/admin if needed."
fi

# HTTP 429 — rate limited
if echo "$RESPONSE" | grep -qE '(HTTP[/ ][0-9.]+[[:space:]]+429|HTTP error.*429|"status":\s*429|429 Too Many Requests|rate limit)'; then
  suggest "Trello API returned HTTP 429 (rate limited). Wait a moment and retry the request. If this persists, reduce the frequency of API calls."
fi

# HTTP 400 — bad request, likely wrong parameters
if echo "$RESPONSE" | grep -qE '(HTTP[/ ][0-9.]+[[:space:]]+400|HTTP error.*400|"status":\s*400|400 Bad Request)'; then
  suggest "Trello API returned HTTP 400 (bad request). One or more parameters may be incorrect. Run: spec-manager.sh query <operation> to check the expected parameter names and types for this endpoint."
fi

# HTTP 5xx — server error
if echo "$RESPONSE" | grep -qE '(HTTP[/ ][0-9.]+[[:space:]]+5[0-9]{2}|HTTP error.*5[0-9]{2}|"status":\s*5[0-9]{2}|50[0-9] |502 Bad Gateway|503 Service Unavailable|504 Gateway Timeout)'; then
  suggest "Trello API returned a server error (5xx). This is likely a temporary issue on Trello's side. Wait a moment and retry the request."
fi

# Invalid ID — common when card/board IDs are wrong or stale
if echo "$RESPONSE_LOWER" | grep -qE '(invalid id|invalid objectid|invalid value for id)'; then
  suggest "Trello API reported an invalid ID. Verify the card, board, or object ID is correct. IDs are 24-character hex strings — check for typos or stale references."
fi

# Generic fallback: catch "Error: HTTP {code}" from trello.sh output
if echo "$RESPONSE_LOWER" | grep -qE '^error: http [0-9]+'; then
  code=$(echo "$RESPONSE" | grep -oE 'HTTP [0-9]+' | grep -oE '[0-9]+' | head -1)
  suggest "Trello API returned an error (HTTP ${code:-unknown}). Check the error message above and retry. If the endpoint seems wrong, run: spec-manager.sh update-spec to refresh the cached OpenAPI spec."
fi

# No error detected
exit 0
