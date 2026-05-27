#!/usr/bin/env python3
"""PostToolUse hook: after a Trello card is updated, check if other cards
reference it (via ## Dependencies or attachments) and remind Claude to
consider cascading changes to those cross-correlated cards.

Fires on any substantive card mutation (PUT, POST to card sub-resources,
DELETE of checklist items, etc.) — not just column moves.
"""

from __future__ import annotations

import json
import re
import sys


CARD_PATH_RE = re.compile(r"/cards/([0-9a-fA-F]{24})")
MUTATION_RE = re.compile(r"(PUT|POST|DELETE)\s")


REMINDER_TEMPLATE = (
    "CASCADE CHECK: You just modified Trello card %CARD_ID%. Other cards may "
    "reference this one as a dependency. To check for cascading impacts:\n\n"
    "1. Fetch this card's details to understand what changed\n"
    "2. Search the board for cards that reference this card:\n"
    "   - Cards with this card's URL or ID in their ## Dependencies section\n"
    "   - Cards with attachments linking to this card\n"
    "3. For each cross-correlated card, consider:\n"
    "   - If this card moved to Done, dependent cards may now be unblocked "
    "(move from Todo to Doing)\n"
    "   - If this card's scope changed, dependent cards may need description "
    "updates\n"
    "   - If this card was re-labelled, dependent cards may need label "
    "alignment\n"
    "   - If checklist items were completed, dependent cards waiting on "
    "those items should be notified\n\n"
    "Use: ${CLAUDE_PLUGIN_ROOT}/scripts/trello.py GET /search query=\"%CARD_ID%\" "
    "modelTypes=cards idBoards=<board-id>\n"
    "Or check attachments: ${CLAUDE_PLUGIN_ROOT}/scripts/trello.py GET "
    "/cards/<dependent-card-id>/attachments"
)


def main() -> None:
    try:
        raw = sys.stdin.read()
        if not raw:
            return
        try:
            payload = json.loads(raw)
        except json.JSONDecodeError:
            return

        command = (payload.get("tool_input") or {}).get("command") or ""
        if not command:
            return

        # Normalise path separators so Windows commands (backslash) still
        # match the substring check. Method/path regexes run against the
        # original command — they don't care about separators.
        norm_command = command.replace("\\", "/")

        # Only act on trello.py mutation commands targeting cards
        if "scripts/trello.py" not in norm_command:
            return

        if not MUTATION_RE.search(command):
            return

        match = CARD_PATH_RE.search(command)
        if not match:
            return

        card_id = match.group(1)
        msg = REMINDER_TEMPLATE.replace("%CARD_ID%", card_id)

        output = {
            "hookSpecificOutput": {
                "hookEventName": "PostToolUse",
                "additionalContext": msg,
            }
        }
        json.dump(output, sys.stdout)
        sys.stdout.write("\n")
    except Exception:
        return


if __name__ == "__main__":
    main()
