#!/usr/bin/env python3
"""Trello API wrapper.

Usage: trello.py <METHOD> <path> [key=value ...]

Values are automatically URL-encoded — pass them as plain text.

Examples:
  trello.py GET /members/me
  trello.py GET /boards/abc123/lists
  trello.py POST /cards name=My Task idList=abc123
  trello.py PUT /cards/abc123 "name=Q&A Session"
  trello.py DELETE /cards/abc123
  trello.py POST /cards/abc123/attachments file=@/path/to/doc.pdf
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from urllib.parse import quote

BASE_URL = "https://api.trello.com/1"


def err(msg: str) -> None:
    print(msg, file=sys.stderr)


def usage_and_exit() -> None:
    err("Usage: trello.py <METHOD> <path> [key=value ...]")
    err("  METHOD   GET, POST, PUT, DELETE")
    err("  path     API path, e.g. /boards/{id}")
    err("  params   Query params as key=value pairs")
    sys.exit(1)


def pretty_print_json(path: Path) -> str:
    """Pretty-print JSON file content. Tries jq, falls back to Python."""
    try:
        result = subprocess.run(
            ["jq", ".", str(path)],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode == 0:
            return result.stdout
    except FileNotFoundError:
        pass
    try:
        with path.open("r", encoding="utf-8") as fh:
            data = json.load(fh)
        return json.dumps(data, indent=2) + "\n"
    except (OSError, json.JSONDecodeError):
        try:
            return path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            return ""


def main() -> None:
    api_key = os.environ.get("TRELLO_API_KEY")
    if not api_key:
        err("Error: TRELLO_API_KEY is not set")
        sys.exit(1)

    token = os.environ.get("TRELLO_TOKEN")
    if not token:
        err("Error: TRELLO_TOKEN is not set")
        sys.exit(1)

    if len(sys.argv) < 3:
        usage_and_exit()

    method = sys.argv[1].upper()
    api_path = sys.argv[2]
    if not api_path.startswith("/"):
        api_path = f"/{api_path}"
    params = sys.argv[3:]

    query_params: list[tuple[str, str]] = []
    file_params: list[str] = []

    for param in params:
        if "=@" in param:
            file_params.append(param)
        else:
            key, _, value = param.partition("=")
            query_params.append((key, value))

    query_pairs = [f"key={api_key}", f"token={token}"]
    for key, value in query_params:
        query_pairs.append(f"{key}={quote(value, safe='')}")
    query = "&".join(query_pairs)
    url = f"{BASE_URL}{api_path}?{query}"

    tmp = tempfile.NamedTemporaryFile(
        prefix="trello-", suffix=".json", delete=False
    )
    tmp_path = Path(tmp.name)
    tmp.close()

    try:
        curl_args = [
            "curl",
            "-s",
            "-o", str(tmp_path),
            "-w", "%{http_code}",
            "-X", method,
        ]
        for fparam in file_params:
            curl_args.extend(["-F", fparam])
        curl_args.append(url)

        try:
            result = subprocess.run(
                curl_args,
                capture_output=True,
                text=True,
                check=False,
            )
        except FileNotFoundError:
            err("Error: 'curl' is required but not installed or not in PATH.")
            sys.exit(1)

        if result.returncode != 0:
            err(f"Error: curl failed (exit {result.returncode})")
            if result.stderr:
                err(result.stderr.rstrip())
            sys.exit(1)

        http_code_str = result.stdout.strip()
        try:
            http_code = int(http_code_str)
        except ValueError:
            err(f"Error: unexpected curl output: {http_code_str!r}")
            sys.exit(1)

        body = pretty_print_json(tmp_path)

        if http_code >= 400:
            # Mirror bash behaviour: emit error + body to BOTH stdout and stderr
            # in a single block to prevent interleaving.
            block = f"Error: HTTP {http_code}\n{body}"
            sys.stdout.write(block)
            sys.stdout.flush()
            sys.stderr.write(block)
            sys.stderr.flush()
            sys.exit(1)

        sys.stdout.write(body)
    finally:
        try:
            tmp_path.unlink()
        except OSError:
            pass


if __name__ == "__main__":
    main()
