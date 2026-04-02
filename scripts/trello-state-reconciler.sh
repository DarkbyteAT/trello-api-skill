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

if grep -qE 'trello\.sh (GET|POST|PUT|DELETE) /cards/' "$TRANSCRIPT_PATH"; then
  CARD_REFERENCED=true
elif grep -qE 'https://trello\.com/c/' "$TRANSCRIPT_PATH"; then
  CARD_REFERENCED=true
elif grep -qE '/cards/[0-9a-f]{24}' "$TRANSCRIPT_PATH"; then
  CARD_REFERENCED=true
fi

# If no cards were referenced, nothing to reconcile
if [[ "$CARD_REFERENCED" != "true" ]]; then
  exit 0
fi

# Patterns that indicate board state was actually updated.
# Consolidated to avoid redundant/overlapping patterns.
CARD_UPDATED=false

# Card moves via query params: trello.sh PUT /cards/{id} idList={listId}
if grep -qE 'trello\.sh PUT /cards/[0-9a-f]{24}.*idList=' "$TRANSCRIPT_PATH"; then
  CARD_UPDATED=true
# General card PUT (catches any update to a card)
elif grep -qE 'trello\.sh PUT /cards/[0-9a-f]{24}' "$TRANSCRIPT_PATH"; then
  CARD_UPDATED=true
# Label changes
elif grep -qE 'trello\.sh (PUT|POST) /cards/.*/idLabels' "$TRANSCRIPT_PATH"; then
  CARD_UPDATED=true
# Comments
elif grep -qE 'trello\.sh POST /cards/.*/actions/comments' "$TRANSCRIPT_PATH"; then
  CARD_UPDATED=true
# Checklist item updates
elif grep -qE 'trello\.sh (PUT|DELETE) /cards/.*/checkItem' "$TRANSCRIPT_PATH"; then
  CARD_UPDATED=true
elif grep -qE 'trello\.sh PUT /checkitems/' "$TRANSCRIPT_PATH"; then
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
