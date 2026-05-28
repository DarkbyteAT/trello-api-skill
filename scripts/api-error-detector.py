#!/usr/bin/env python3
"""PostToolUse hook: detect Trello API errors and suggest recovery actions.

Reads JSON from stdin (Claude Code PostToolUse format), checks if the
command invoked a Trello plugin script, inspects the response for HTTP
errors, and outputs actionable suggestions as additionalContext.

NOTE: trello.py writes "Error: HTTP {code}" and the response body to
both stdout and stderr on failures. Claude Code's Bash tool_response
captures this output, so these patterns should match.
"""

from __future__ import annotations

import json
import re
import sys


# Patterns mirror the bash version (case-insensitive). Each is a (regex,
# suggestion) tuple; the first match wins. Order matches the bash original.
PATTERNS: list[tuple[re.Pattern[str], str]] = [
    (
        re.compile(
            r"(http[/ ][0-9.]+\s+404|http error.*404|\"status\":\s*404|"
            r"404 not found)",
            re.IGNORECASE,
        ),
        "Trello API returned HTTP 404. The endpoint may have changed. Run: "
        "spec-manager.py update-spec to refresh the cached OpenAPI spec, "
        "then re-query for the correct endpoint path.",
    ),
    (
        re.compile(
            r"(http[/ ][0-9.]+\s+(401|403)|http error.*(401|403)|"
            r"\"status\":\s*(401|403)|unauthorized|forbidden|"
            r"invalid (app)?key|invalid token)",
            re.IGNORECASE,
        ),
        "Trello API returned an authentication/authorisation error. Check "
        "that TRELLO_API_KEY and TRELLO_TOKEN are set correctly in your "
        "shell profile and have not expired. Re-generate credentials at "
        "https://trello.com/power-ups/admin if needed.",
    ),
    (
        re.compile(
            r"(http[/ ][0-9.]+\s+429|http error.*429|\"status\":\s*429|"
            r"rate limit)",
            re.IGNORECASE,
        ),
        "Trello API returned HTTP 429 (rate limited). Wait a moment and "
        "retry the request. If this persists, reduce the frequency of API "
        "calls.",
    ),
    (
        re.compile(
            r"(http[/ ][0-9.]+\s+400|http error.*400|\"status\":\s*400|"
            r"400 bad request)",
            re.IGNORECASE,
        ),
        "Trello API returned HTTP 400 (bad request). One or more parameters "
        "may be incorrect. Run: spec-manager.py query <operation> to check "
        "the expected parameter names and types for this endpoint.",
    ),
    (
        re.compile(
            r"(http[/ ][0-9.]+\s+5[0-9]{2}|http error.*5[0-9]{2}|"
            r"\"status\":\s*5[0-9]{2}|502 bad gateway|503 service unavailable|"
            r"504 gateway timeout)",
            re.IGNORECASE,
        ),
        "Trello API returned a server error (5xx). This is likely a "
        "temporary issue on Trello's side. Wait a moment and retry the "
        "request.",
    ),
    (
        re.compile(
            r"(invalid id|invalid objectid|invalid value for id)",
            re.IGNORECASE,
        ),
        "Trello API reported an invalid ID. Verify the card, board, or "
        "object ID is correct. IDs are 24-character hex strings — check for "
        "typos or stale references.",
    ),
]

# Fallback: any "Error: HTTP {code}" line emitted by trello.py
FALLBACK_RE = re.compile(r"(?im)^error: http ([0-9]+)")


def emit(msg: str) -> None:
    output = {
        "hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": msg,
        }
    }
    json.dump(output, sys.stdout)
    sys.stdout.write("\n")


def extract_response_text(value) -> str:
    """tool_response may be a string or an object — flatten to text."""
    if isinstance(value, str):
        return value
    if value is None:
        return ""
    try:
        return json.dumps(value)
    except (TypeError, ValueError):
        return str(value)


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

        if "trello.py" not in command and "spec-manager.py" not in command:
            return

        # Mirror the bash version's exit-code check: skip when 0.
        exit_code = (
            (payload.get("tool_input") or {}).get("exit_code")
            if payload.get("tool_input") else None
        )
        if exit_code is None:
            exit_code = payload.get("exit_code", 0)
        try:
            exit_code = int(exit_code)
        except (TypeError, ValueError):
            exit_code = 0
        if exit_code == 0:
            return

        response = extract_response_text(payload.get("tool_response"))
        if not response:
            return

        for pattern, msg in PATTERNS:
            if pattern.search(response):
                emit(msg)
                return

        fallback = FALLBACK_RE.search(response)
        if fallback:
            code = fallback.group(1)
            emit(
                f"Trello API returned an error (HTTP {code}). Check the "
                "error message above and retry. If the endpoint seems wrong, "
                "run: spec-manager.py update-spec to refresh the cached "
                "OpenAPI spec."
            )
    except Exception:
        return


if __name__ == "__main__":
    main()
