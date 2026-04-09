#!/usr/bin/env bash
set -euo pipefail

# Stop hook: check if the session referenced Trello cards without updating
# board state. If so, block the stop and remind Claude to reconcile.
#
# Reads JSON from stdin (Stop hook format with transcript_path and
# stop_hook_active). Scans the transcript JSONL for Trello card references
# and update operations to decide whether board state was reconciled.

INPUT=$(cat)

# Prevent infinite loops — if this hook already fired, let the stop proceed
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
if [[ "$STOP_HOOK_ACTIVE" == "true" ]]; then
  exit 0
fi

# Read the transcript path
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // ""')
if [[ -z "$TRANSCRIPT_PATH" || ! -f "$TRANSCRIPT_PATH" ]]; then
  exit 0
fi

# Extract only real Bash tool invocations from the transcript.
#
# Grepping the raw JSONL text is unsafe: each record is a single (very long)
# line, so a greedy regex like `trello\.sh ... .*/cards` will happily span
# thousands of characters and correlate two unrelated strings that share a
# record — e.g. a `trello.sh GET /boards` example in one skill's description
# and the literal `/cards` in an unrelated skill's description loaded in the
# same turn. That produced false-positive blocks on sessions that never
# touched Trello at all.
#
# Only assistant Bash tool_use events can actually execute trello.sh, so we
# pull out just those command strings and match against them.
BASH_COMMANDS=$(jq -r '
  select(.type == "assistant")
  | .message.content[]?
  | select(.type == "tool_use" and .name == "Bash")
  | .input.command // empty
' "$TRANSCRIPT_PATH" 2>/dev/null || true)

if [[ -z "$BASH_COMMANDS" ]]; then
  exit 0
fi

# Patterns that indicate a Trello card was referenced.
# The path token is whitespace-free so it can't bridge unrelated fragments.
CARD_REFERENCED=false
if grep -qE 'trello\.sh (GET|POST|PUT|DELETE) [^[:space:]]*/cards' <<<"$BASH_COMMANDS"; then
  CARD_REFERENCED=true
fi

# If no cards were referenced, nothing to reconcile
if [[ "$CARD_REFERENCED" != "true" ]]; then
  exit 0
fi

# Any non-GET trello.sh call counts as board-state reconciliation. HTTP GET
# is read-only by definition, so anything else — POST, PUT, DELETE, PATCH —
# means the session wrote *something* to Trello. This matches the semantics
# of the check (did you reconcile board state?) and avoids an allowlist of
# paths that drifts out of date every time Trello adds a sub-resource. The
# previous allowlist notably missed POST /checklists/{id}/checkItems, which
# is how checklist items are actually added and accounted for ~75% of real
# reconciliation writes.
CARD_UPDATED=false
if grep -qE 'trello\.sh (POST|PUT|DELETE|PATCH)\b' <<<"$BASH_COMMANDS"; then
  CARD_UPDATED=true
fi

# If cards were referenced but no updates were made, block the stop
if [[ "$CARD_UPDATED" != "true" ]]; then
  cat <<'EOF'
{"decision":"block","reason":"You referenced Trello cards during this session but didn't update the board state. Check: (1) Should any cards move between columns (Todo→Doing→Reviewing→Done)? (2) Are there checklist items to tick? (3) Should any comments be added to cards? Please reconcile Trello board state before finishing."}
EOF
  exit 0
fi

# Cards were referenced and updates were made — allow the stop
exit 0
