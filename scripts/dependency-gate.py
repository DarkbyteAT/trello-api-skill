#!/usr/bin/env python3
"""UserPromptSubmit hook: injects a dependency-check reminder when the user
appears to be picking up or starting work on a Trello card.
"""

from __future__ import annotations

import json
import re
import sys


ACTION_RE = re.compile(
    r"(pick up|start work|work on|implement|begin|tackle)", re.IGNORECASE
)
TARGET_RE = re.compile(r"(card|trello)", re.IGNORECASE)
URL_RE = re.compile(r"trello\.com/c/", re.IGNORECASE)


REMINDER = (
    "DEPENDENCY CHECK: Before starting work on this card, verify its "
    "dependencies are in Done and any dependent PRs are merged to main."
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

        prompt = payload.get("prompt") or ""
        if not prompt:
            return

        matched = (
            (ACTION_RE.search(prompt) and TARGET_RE.search(prompt))
            or URL_RE.search(prompt)
        )
        if not matched:
            return

        output = {
            "hookSpecificOutput": {
                "hookEventName": "UserPromptSubmit",
                "additionalContext": REMINDER,
            }
        }
        json.dump(output, sys.stdout)
        sys.stdout.write("\n")
    except Exception:
        return


if __name__ == "__main__":
    main()
