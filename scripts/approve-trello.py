#!/usr/bin/env python3
"""PreToolUse hook: auto-approve Bash calls to Trello plugin scripts.

Reads JSON from stdin (Claude Code hook input), checks if the command
targets a plugin script, and returns an allow decision if safe.

Safety: strips quoted strings first, then rejects commands containing
unquoted shell chaining operators (&&, ||, ;, backticks, subshells).
Pipes (|) are allowed only when every downstream command is on the
SAFE_PIPE_TARGETS whitelist. Metacharacters inside quoted values
(e.g. Markdown backticks in card descriptions) are safe.

Always exits 0 (fail open) — on any error or rejection, the hook is
silent and Claude Code falls back to normal permission prompts.
"""

from __future__ import annotations

import json
import os
import re
import sys

SAFE_PIPE_TARGETS = {
    "jq", "grep", "head", "tail", "wc", "sort", "uniq",
    "cat", "less", "tee", "cut", "tr", "sed", "awk", "column",
}

REJECT_PATTERNS = ("&&", "||", ";", "`", "$(", "<(")

LITERAL_PREFIX = "${CLAUDE_PLUGIN_ROOT}/scripts/"

APPROVAL_JSON = (
    '{"hookSpecificOutput":{"hookEventName":"PreToolUse",'
    '"permissionDecision":"allow",'
    '"permissionDecisionReason":"Auto-approved: Trello plugin script"}}'
)


def strip_quoted(command: str) -> str:
    """Strip double-quoted strings first, then single-quoted strings.

    Mirrors the bash original: newlines collapsed first, then sed strips
    `"[^"]*"` and `'[^']*'`. Double-quoted strings are removed FIRST so
    that apostrophes inside double-quoted values are consumed before the
    single-quote pass.
    """
    collapsed = command.replace("\n", " ")
    no_double = re.sub(r'"[^"]*"', "", collapsed)
    no_single = re.sub(r"'[^']*'", "", no_double)
    return no_single


def is_pipe_chain_safe(unquoted: str) -> bool:
    """Validate every downstream segment of a pipe chain.

    Returns True if there are no pipes or every command after the first
    pipe starts with a SAFE_PIPE_TARGETS entry.
    """
    if "|" not in unquoted:
        return True

    # Split on pipe; ignore the first segment (the trello.py call itself)
    segments = unquoted.split("|")
    for segment in segments[1:]:
        segment = segment.strip()
        if not segment:
            return False
        cmd_name = segment.split(" ", 1)[0]
        if cmd_name not in SAFE_PIPE_TARGETS:
            return False
    return True


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

        plugin_root = os.environ.get("CLAUDE_PLUGIN_ROOT", "")
        resolved_prefix = f"{plugin_root}/scripts/" if plugin_root else None

        matched = False
        if resolved_prefix and command.startswith(resolved_prefix):
            matched = True
        elif command.startswith(LITERAL_PREFIX):
            matched = True

        if not matched:
            return

        unquoted = strip_quoted(command)

        for pattern in REJECT_PATTERNS:
            if pattern in unquoted:
                return

        if not is_pipe_chain_safe(unquoted):
            return

        sys.stdout.write(APPROVAL_JSON + "\n")
    except Exception:
        # Fail open — never block legitimate calls
        return


if __name__ == "__main__":
    main()
