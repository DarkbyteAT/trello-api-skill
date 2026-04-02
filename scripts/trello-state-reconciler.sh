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

# Grep the file directly instead of buffering into a variable — avoids
# memory issues and slow piping for large transcripts.

# Patterns that indicate a Trello card was referenced
CARD_REFERENCED=false

# Only match actual trello.sh tool calls — not card URLs or IDs that may
# appear in user messages or file contents read by Claude.
if grep -qE 'trello\.sh (GET|POST|PUT|DELETE) .*/cards' "$TRANSCRIPT_PATH"; then
  CARD_REFERENCED=true
fi

# If no cards were referenced, nothing to reconcile
if [[ "$CARD_REFERENCED" != "true" ]]; then
  exit 0
fi

# Any POST, PUT, or DELETE targeting cards or checkitems counts as an update.
# Single grep pass covers creation, mutation, deletion, and sub-resources.
CARD_UPDATED=false
if grep -qE 'trello\.sh (POST|PUT|DELETE) /(cards|checkitems)' "$TRANSCRIPT_PATH"; then
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
