#!/usr/bin/env bash
set -euo pipefail

# PreToolUse hook: auto-approve Bash calls to Trello plugin scripts.
# Reads JSON from stdin (Claude Code hook input), checks if the command
# targets a plugin script, and returns an allow decision if safe.
#
# Safety: rejects commands containing shell chaining operators to prevent
# injection via "trello.sh args && malicious-command".

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Nothing to check if command is empty
if [[ -z "$COMMAND" ]]; then
  exit 0
fi

# Resolve the plugin scripts prefix from the environment
RESOLVED_PREFIX="${CLAUDE_PLUGIN_ROOT}/scripts/"

# Also match the literal env var form Claude might emit
LITERAL_PREFIX='${CLAUDE_PLUGIN_ROOT}/scripts/'

# Check if command starts with either form
MATCHED=false
if [[ "$COMMAND" == "${RESOLVED_PREFIX}"* ]]; then
  MATCHED=true
elif [[ "$COMMAND" == '${CLAUDE_PLUGIN_ROOT}/scripts/'* ]]; then
  MATCHED=true
fi

if [[ "$MATCHED" != "true" ]]; then
  exit 0
fi

# Security: reject commands with shell chaining operators
for pattern in '&&' '||' ';' '|' '`' '$(' '<(' '>'; do
  if [[ "$COMMAND" == *"$pattern"* ]]; then
    exit 0
  fi
done

# Auto-approve
cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"Auto-approved: Trello plugin script"}}
EOF
