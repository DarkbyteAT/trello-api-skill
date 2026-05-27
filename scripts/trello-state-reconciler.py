#!/usr/bin/env python3
"""Stop hook: check if the session referenced Trello cards without updating
board state. If so, block the stop and remind Claude to reconcile.

Reads JSON from stdin (Stop hook format with transcript_path and
stop_hook_active). Scans the transcript JSONL for Trello card references
and update operations to decide whether board state was reconciled.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


CARD_REFERENCE_RE = re.compile(
    r"trello\.py (?:GET|POST|PUT|DELETE) \S*/cards"
)
MUTATION_RE = re.compile(r"trello\.py (?:POST|PUT|DELETE|PATCH)\b")


BLOCK_JSON = (
    '{"decision":"block","reason":"You referenced Trello cards during this '
    "session but didn't update the board state. Check: (1) Should any cards "
    "move between columns (Todo→Doing→Reviewing→Done)? "
    "(2) Are there checklist items to tick? (3) Should any comments be "
    'added to cards? Please reconcile Trello board state before finishing."}'
)


def extract_bash_commands(transcript_path: Path) -> list[str]:
    """Pull command strings from assistant Bash tool_use events only.

    Mirrors the bash version's jq filter: avoids matching against the raw
    JSONL text (which would let regexes span unrelated records).
    """
    commands: list[str] = []
    try:
        with transcript_path.open("r", encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    record = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if record.get("type") != "assistant":
                    continue
                content = (record.get("message") or {}).get("content")
                if not isinstance(content, list):
                    continue
                for item in content:
                    if not isinstance(item, dict):
                        continue
                    if item.get("type") != "tool_use":
                        continue
                    if item.get("name") != "Bash":
                        continue
                    cmd = (item.get("input") or {}).get("command")
                    if isinstance(cmd, str) and cmd:
                        commands.append(cmd)
    except OSError:
        return []
    return commands


def main() -> None:
    try:
        raw = sys.stdin.read()
        if not raw:
            return
        try:
            payload = json.loads(raw)
        except json.JSONDecodeError:
            return

        if payload.get("stop_hook_active") is True:
            return

        transcript_path = payload.get("transcript_path") or ""
        if not transcript_path:
            return
        path = Path(transcript_path)
        if not path.is_file():
            return

        commands = extract_bash_commands(path)
        if not commands:
            return

        haystack = "\n".join(commands)

        if not CARD_REFERENCE_RE.search(haystack):
            return

        if MUTATION_RE.search(haystack):
            return

        sys.stdout.write(BLOCK_JSON + "\n")
    except Exception:
        return


if __name__ == "__main__":
    main()
