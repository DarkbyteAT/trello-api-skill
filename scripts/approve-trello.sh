#!/usr/bin/env bash
set -euo pipefail

# PreToolUse hook: auto-approve Bash calls to Trello plugin scripts.
# Reads JSON from stdin (Claude Code hook input), checks if the command
# targets a plugin script, and returns an allow decision if safe.
#
# Safety: strips quoted strings first, then rejects commands containing
# unquoted shell chaining operators (&&, ||, ;, backticks, subshells).
# Pipes (|) are allowed only when every downstream command is on the
# SAFE_PIPE_TARGETS whitelist. Metacharacters inside quoted values
# (e.g. Markdown backticks in card descriptions) are safe.

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

# Whitelist of safe read-only tools allowed after a pipe
SAFE_PIPE_TARGETS="jq grep head tail wc sort uniq cat less tee cut tr sed awk column"

# Strip quoted strings so shell metacharacters inside values (e.g. backticks
# in Markdown inline code, pipes in jq filters) are not mistaken for shell syntax.
# Collapse newlines first so multiline quoted values (card descriptions) are
# handled correctly — BSD sed only matches within single lines.
# IMPORTANT: double-quoted strings are stripped FIRST so that apostrophes
# inside double-quoted values (e.g. "the request's team") are consumed before
# the single-quote pass, which would otherwise treat them as delimiters.
UNQUOTED=$(printf '%s' "$COMMAND" | tr '\n' ' ' | sed 's/"[^"]*"//g' | sed "s/'[^']*'//g")

# Security: reject commands with shell chaining operators (checked against
# the unquoted command so that metacharacters inside quoted values are safe)
for pattern in '&&' '||' ';' '`' '$(' '<('; do
  if [[ "$UNQUOTED" == *"$pattern"* ]]; then
    exit 0
  fi
done

# If the command contains actual shell pipes, validate every downstream segment
if [[ "$UNQUOTED" == *"|"* ]]; then
  # Split on pipe and check each segment after the first (the trello.sh call)
  REST="${UNQUOTED#*|}"
  while [[ -n "$REST" ]]; do
    # Extract the current pipe segment (up to the next pipe, or the rest)
    if [[ "$REST" == *"|"* ]]; then
      SEGMENT="${REST%%|*}"
      REST="${REST#*|}"
    else
      SEGMENT="$REST"
      REST=""
    fi

    # Trim leading/trailing whitespace
    SEGMENT=$(echo "$SEGMENT" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Extract the command name (first word)
    CMD_NAME="${SEGMENT%% *}"

    # Check against whitelist
    ALLOWED=false
    for safe in $SAFE_PIPE_TARGETS; do
      if [[ "$CMD_NAME" == "$safe" ]]; then
        ALLOWED=true
        break
      fi
    done

    if [[ "$ALLOWED" != "true" ]]; then
      exit 0
    fi
  done
fi

# Auto-approve
cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"Auto-approved: Trello plugin script"}}
EOF
