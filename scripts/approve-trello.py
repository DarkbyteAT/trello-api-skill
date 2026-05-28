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

# Explicit allow-list of script basenames that may be auto-approved.
# Dropping a new file into scripts/ should be a deliberate decision, not
# an accidental side-effect of the prefix match.
ALLOWED_SCRIPTS = {"trello.py", "spec-manager.py"}

# Optional leading interpreter token. Matches `python`, `python3`, `py`,
# or `py -3` followed by whitespace. Anchored with ^ and bounded by \s so
# `evil-python` does not match.
INTERPRETER_PATTERN = re.compile(r"^(?:python3?|py(?:\s+-3)?)\s+")

APPROVAL_JSON = (
    '{"hookSpecificOutput":{"hookEventName":"PreToolUse",'
    '"permissionDecision":"allow",'
    '"permissionDecisionReason":"Auto-approved: Trello plugin script"}}'
)


def strip_quoted(command: str) -> str:
    """Strip double-quoted strings first, then single-quoted strings.

    Double-quoted strings are removed FIRST so that apostrophes inside
    double-quoted values are consumed before the single-quote pass.
    """
    no_double = re.sub(r'"[^"]*"', "", command)
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

        # Defence: raw \n or \r in an unquoted command acts as a shell
        # command separator (newline ≡ `;`). Reject before any other
        # check so a payload like "trello.py GET /me\ntouch /tmp/PWNED"
        # can't slip past the chaining-operator scan.
        if "\n" in command or "\r" in command:
            return

        plugin_root = os.environ.get("CLAUDE_PLUGIN_ROOT", "")

        # Defence-in-depth: if CLAUDE_PLUGIN_ROOT is missing, refuse to
        # auto-approve. Production Claude Code always sets it; treating an
        # unset value as "match anything literal" would be permissive in
        # test/dev environments where the variable is absent.
        if not plugin_root:
            return

        # Strip an optional leading interpreter token so that Windows
        # invocations like `python ${CLAUDE_PLUGIN_ROOT}/scripts/trello.py`
        # and `py -3 ...` get the same treatment as the bare script path.
        # The shell-chaining and pipe checks still run against the ORIGINAL
        # command so we don't change the meaning of subsequent metachars.
        remainder = INTERPRETER_PATTERN.sub("", command, count=1)

        # Normalise path separators so a Windows CLAUDE_PLUGIN_ROOT (which
        # uses backslashes) matches commands written with either separator.
        # Only used for the prefix/basename checks — the rest of the
        # validation runs against the ORIGINAL command so backslashes
        # inside quoted card descriptions are not tampered with.
        norm_remainder = remainder.replace("\\", "/")
        norm_resolved = f"{plugin_root}/scripts/".replace("\\", "/")

        if not (
            norm_remainder.startswith(norm_resolved)
            or norm_remainder.startswith(LITERAL_PREFIX)
        ):
            return

        # Basename allow-list: enforce that the targeted script is one
        # we actually intend to auto-approve. Use the normalised form so
        # both separator styles work; tolerate either in the raw token too.
        first_token = norm_remainder.split(maxsplit=1)[0] if norm_remainder else ""
        basename = first_token.rsplit("/", 1)[-1]
        if basename not in ALLOWED_SCRIPTS:
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
