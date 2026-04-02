#!/usr/bin/env bash
# UserPromptSubmit hook: injects a dependency-check reminder when the user
# appears to be picking up or starting work on a Trello card.

set -euo pipefail

# Read the hook payload from stdin
payload="$(cat)"

# Extract the prompt text (lowercase for case-insensitive matching)
prompt="$(printf '%s' "$payload" | jq -r '.prompt // empty' | tr '[:upper:]' '[:lower:]')"

if [[ -z "$prompt" ]]; then
  exit 0
fi

# Pattern 1: action words combined with card/trello keywords
action_pattern='(pick up|start work|work on|implement|begin|tackle)'
target_pattern='(card|trello)'

# Pattern 2: contains a Trello card short URL
url_pattern='trello\.com/c/'

if [[ "$prompt" =~ $action_pattern ]] && [[ "$prompt" =~ $target_pattern ]]; then
  matched=true
elif [[ "$prompt" =~ $url_pattern ]]; then
  matched=true
else
  exit 0
fi

# Inject dependency-check reminder without blocking the prompt
jq -n '{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "DEPENDENCY CHECK REMINDER: Before starting work on this Trello card, check its dependencies. Use trello.sh to fetch the card details and verify: (1) All cards listed in the Dependencies section are in the Done column, (2) Any dependent PRs have been merged to main. If dependencies are not met, inform the user and suggest working on dependencies first or removing the dependency if it is no longer relevant."
  }
}'

exit 0
