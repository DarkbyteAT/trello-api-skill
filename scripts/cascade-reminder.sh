#!/usr/bin/env bash
set -euo pipefail

# PostToolUse hook: after a Trello card is updated, check if other cards
# reference it (via ## Dependencies or attachments) and remind Claude to
# consider cascading changes to those cross-correlated cards.
#
# Fires on any substantive card mutation (PUT, POST to card sub-resources,
# DELETE of checklist items, etc.) — not just column moves.

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
COMMAND=$(jq -r '.tool_input.command // ""' <<< "$INPUT")

if [[ -z "$COMMAND" ]]; then
  exit 0
fi

# Only act on trello.sh mutation commands (PUT, POST, DELETE) targeting cards
if [[ "$COMMAND" != *"scripts/trello.sh"* ]]; then
  exit 0
fi

# Must be a mutation (not GET)
if ! echo "$COMMAND" | grep -qE '(PUT|POST|DELETE)[[:space:]]'; then
  exit 0
fi

# Must target a card or card sub-resource (case-insensitive for hex IDs)
if ! echo "$COMMAND" | grep -iqE '/cards/[0-9a-f]{24}'; then
  exit 0
fi

# Extract the card ID from the command (case-insensitive)
CARD_ID=$(echo "$COMMAND" | grep -oiE '/cards/([0-9a-f]{24})' | grep -oiE '[0-9a-f]{24}' | head -1)

if [[ -z "$CARD_ID" ]]; then
  exit 0
fi

# Build the reminder. We don't fetch the board here (that would be slow
# and require TRELLO_API_KEY/TOKEN which hooks don't reliably have).
# Instead, we tell Claude what to check and how.
read -r -d '' MSG <<'REMINDER' || true
CASCADE CHECK: You just modified Trello card %CARD_ID%. Other cards may reference this one as a dependency. To check for cascading impacts:

1. Fetch this card's details to understand what changed
2. Search the board for cards that reference this card:
   - Cards with this card's URL or ID in their ## Dependencies section
   - Cards with attachments linking to this card
3. For each cross-correlated card, consider:
   - If this card moved to Done, dependent cards may now be unblocked (move from Todo to Doing)
   - If this card's scope changed, dependent cards may need description updates
   - If this card was re-labelled, dependent cards may need label alignment
   - If checklist items were completed, dependent cards waiting on those items should be notified

Use: ${CLAUDE_PLUGIN_ROOT}/scripts/trello.sh GET /search query="%CARD_ID%" modelTypes=cards idBoards=<board-id>
Or check attachments: ${CLAUDE_PLUGIN_ROOT}/scripts/trello.sh GET /cards/<dependent-card-id>/attachments
REMINDER

MSG="${MSG//%CARD_ID%/$CARD_ID}"

jq -n --arg ctx "$MSG" \
  '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":$ctx}}'

exit 0
