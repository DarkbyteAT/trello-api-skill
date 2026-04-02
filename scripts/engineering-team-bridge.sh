#!/usr/bin/env bash
set -euo pipefail

# PostToolUse hook: when a Trello card is fetched, suggest relevant
# engineering-team agents based on the card's labels and description.
# Bridges the trello-api-skill and engineering-team plugins.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Only act on trello.sh GET calls for cards
if [[ "$COMMAND" != *"/scripts/trello.sh"* ]]; then
  exit 0
fi
if ! echo "$COMMAND" | grep -qE 'GET\s+/1/cards/'; then
  exit 0
fi

RESPONSE=$(echo "$INPUT" | jq -r '.tool_response // ""')
if [[ -z "$RESPONSE" ]]; then
  exit 0
fi

# Try to parse response as JSON — if it fails, it's not a card payload
if ! echo "$RESPONSE" | jq -e '.id' >/dev/null 2>&1; then
  exit 0
fi

# Extract labels and description
LABELS=$(echo "$RESPONSE" | jq -r '[.labels[]?.name // empty] | join(", ")' 2>/dev/null || echo "")
DESC=$(echo "$RESPONSE" | jq -r '.desc // ""' 2>/dev/null | tr '[:upper:]' '[:lower:]')
CARD_NAME=$(echo "$RESPONSE" | jq -r '.name // "unknown"' 2>/dev/null)

AGENTS=()
REASONS=()

# Map labels to agents
if echo "$LABELS" | grep -qi "Testing"; then
  AGENTS+=("qa-engineer")
  REASONS+=("qa-engineer (Testing label)")
fi

if echo "$LABELS" | grep -qiE "(Infrastructure|Ci/CD)"; then
  AGENTS+=("devops-engineer")
  REASONS+=("devops-engineer (Infrastructure/CI label)")
fi

if echo "$LABELS" | grep -qi "Critical"; then
  AGENTS+=("staff-architect" "skeptic")
  REASONS+=("staff-architect + skeptic (Critical label — high-risk work)")
fi

# Map description keywords to agents
if echo "$DESC" | grep -qE '(auth|security|pii|token|password|credential|oauth|jwt|oidc|patient data|gdpr)'; then
  # Avoid duplicates
  if [[ ! " ${AGENTS[*]:-} " =~ " security-engineer " ]]; then
    AGENTS+=("security-engineer")
    REASONS+=("security-engineer (security/auth keywords in description)")
  fi
fi

if echo "$DESC" | grep -qE '(frontend|ui |component|react|vue|svelte|css|tailwind|jsx|tsx)'; then
  if [[ ! " ${AGENTS[*]:-} " =~ " frontend-developer " ]]; then
    AGENTS+=("frontend-developer")
    REASONS+=("frontend-developer (frontend keywords in description)")
  fi
fi

if echo "$DESC" | grep -qE '(api|endpoint|database|migration|schema|model|sql|postgres|redis)'; then
  if [[ ! " ${AGENTS[*]:-} " =~ " backend-developer " ]]; then
    AGENTS+=("backend-developer")
    REASONS+=("backend-developer (backend/data keywords in description)")
  fi
fi

# Advocate is always suggested for any card with labels or content matches
if [[ ${#AGENTS[@]} -gt 0 ]]; then
  AGENTS+=("advocate")
  REASONS+=("advocate (always — developer experience)")
fi

# If no meaningful matches, exit silently
if [[ ${#AGENTS[@]} -eq 0 ]]; then
  exit 0
fi

# Build the suggestion message
AGENT_LIST=$(printf '%s, ' "${AGENTS[@]}")
AGENT_LIST="${AGENT_LIST%, }"  # trim trailing comma

REASON_LIST=$(printf '  - %s\n' "${REASONS[@]}")

MSG="ENGINEERING TEAM BRIDGE: Trello card \"${CARD_NAME}\" has labels [${LABELS}]. Suggested agents to consult:
${REASON_LIST}
Consider invoking the engineering-manager to orchestrate a consultation with: ${AGENT_LIST}"

jq -n --arg ctx "$MSG" \
  '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":$ctx}}'

exit 0
