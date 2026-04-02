#!/usr/bin/env bash
set -euo pipefail

# PostToolUse hook: when a Trello card is fetched, suggest relevant
# engineering-team agents based on the card's labels and description.
# Bridges the trello-api-skill and engineering-team plugins.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Only act on trello.sh GET calls for cards
if [[ "$COMMAND" != *"trello.sh"* ]]; then
  exit 0
fi
# Match direct card fetches — supports both 24-char hex IDs and 8-char shortLinks
if ! echo "$COMMAND" | grep -qE 'GET[[:space:]]+/cards/[a-zA-Z0-9]{8,24}([[:space:]]|$)'; then
  exit 0
fi

RESPONSE=$(echo "$INPUT" | jq -r '.tool_response // ""')
if [[ -z "$RESPONSE" ]]; then
  exit 0
fi

# Extract all fields in a single jq pass. If not a card object, bail.
eval "$(echo "$RESPONSE" | jq -r '
  if type == "object" and has("id") then
    @sh "CARD_NAME=\(.name // "unknown")",
    @sh "DESC=\((.desc // "") | ascii_downcase)",
    @sh "LABELS=\([.labels[]?.name // empty] | join(", "))",
    "IS_CARD=true"
  else
    "IS_CARD=false"
  end
' 2>/dev/null || echo "IS_CARD=false")"

if [[ "$IS_CARD" != "true" ]]; then
  exit 0
fi

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
if echo "$DESC" | grep -qE '\b(auth|security|pii|token|password|credential|oauth|jwt|oidc|patient data|gdpr)\b'; then
  # Avoid duplicates
  if [[ ! " ${AGENTS[*]:-} " =~ " security-engineer " ]]; then
    AGENTS+=("security-engineer")
    REASONS+=("security-engineer (security/auth keywords in description)")
  fi
fi

if echo "$DESC" | grep -qE '\b(frontend|ui|component|react|vue|svelte|css|tailwind|jsx|tsx)\b'; then
  if [[ ! " ${AGENTS[*]:-} " =~ " frontend-developer " ]]; then
    AGENTS+=("frontend-developer")
    REASONS+=("frontend-developer (frontend keywords in description)")
  fi
fi

if echo "$DESC" | grep -qE '\b(api|endpoint|database|migration|schema|model|sql|postgres|redis)\b'; then
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
