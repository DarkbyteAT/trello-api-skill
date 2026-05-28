#!/usr/bin/env python3
"""Trello OpenAPI Spec Manager.

Downloads, caches, and queries the Trello REST API OpenAPI spec.
"""

from __future__ import annotations

import datetime as dt
import os
import re
import shutil
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

DEFAULT_CACHE_DIR = Path.home() / ".claude" / "cache" / "trello"
DEFAULT_SPEC_URL = "https://dac-static.atlassian.com/cloud/trello/swagger.v3.json"
DEFAULT_DOCS_URL = (
    "https://developer.atlassian.com/cloud/trello/rest/api-group-actions/"
)

CACHE_DIR = Path(os.environ.get("TRELLO_CACHE_DIR") or DEFAULT_CACHE_DIR)
SPEC_FILE = CACHE_DIR / "swagger.v3.json"
CHECK_FILE = CACHE_DIR / ".last-checked"
SPEC_BASE_URL = os.environ.get("TRELLO_SPEC_URL") or DEFAULT_SPEC_URL
DOCS_URL = os.environ.get("TRELLO_DOCS_URL") or DEFAULT_DOCS_URL


def err(msg: str) -> None:
    print(msg, file=sys.stderr)


def ensure_jq() -> None:
    if shutil.which("jq") is None:
        err("Error: 'jq' is required but not installed.")
        sys.exit(1)


def ensure_cache_dir() -> None:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)


def http_get(url: str, timeout: int = 30) -> bytes | None:
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "trello-api-skill"})
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.read()
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, OSError):
        return None


def fetch_remote_version() -> str:
    """Scrape the current _v=X.Y.Z version from the docs page."""
    body = http_get(DOCS_URL)
    if not body:
        return ""
    try:
        text = body.decode("utf-8", errors="replace")
    except Exception:
        return ""
    match = re.search(r"_v=([0-9]+\.[0-9]+\.[0-9]+)", text)
    return match.group(1) if match else ""


def cached_version() -> str:
    if not CHECK_FILE.is_file():
        return ""
    try:
        lines = CHECK_FILE.read_text(encoding="utf-8").splitlines()
    except OSError:
        return ""
    return lines[1] if len(lines) >= 2 else ""


def cached_date() -> str:
    if not CHECK_FILE.is_file():
        return ""
    try:
        lines = CHECK_FILE.read_text(encoding="utf-8").splitlines()
    except OSError:
        return ""
    return lines[0] if lines else ""


def download_spec(version: str) -> None:
    url = SPEC_BASE_URL
    if version:
        url = f"{SPEC_BASE_URL}?_v={version}"
    err("Downloading Trello OpenAPI spec...")
    body = http_get(url, timeout=60)
    if body is None:
        err(f"Error: Failed to download spec from {url}")
        sys.exit(1)
    try:
        SPEC_FILE.write_bytes(body)
    except OSError as exc:
        err(f"Error: Failed to write spec to {SPEC_FILE}: {exc}")
        sys.exit(1)
    err(f"Spec saved to {SPEC_FILE}")


def write_check_file(version: str) -> None:
    today = dt.date.today().isoformat()
    CHECK_FILE.write_text(f"{today}\n{version}\n", encoding="utf-8")


def cmd_ensure_spec() -> None:
    ensure_cache_dir()
    today = dt.date.today().isoformat()
    last_date = cached_date()

    if last_date == today and SPEC_FILE.is_file():
        err("Spec is up to date (checked today).")
        return

    remote = fetch_remote_version()
    local = cached_version()

    if remote and remote == local and SPEC_FILE.is_file():
        err(f"Spec version unchanged ({remote}), updating check date.")
        write_check_file(remote)
        return

    dl_version = remote or "unknown"
    download_spec(remote)
    write_check_file(dl_version)


def cmd_update_spec() -> None:
    ensure_cache_dir()
    remote = fetch_remote_version()
    dl_version = remote or "unknown"
    download_spec(remote)
    write_check_file(dl_version)
    err(f"Spec force-updated (version: {dl_version}).")


def cmd_query(args: list[str]) -> None:
    if not SPEC_FILE.is_file():
        err("Error: No cached spec found. Run 'ensure-spec' first.")
        sys.exit(1)
    ensure_jq()
    result = subprocess.run(
        ["jq", *args, str(SPEC_FILE)],
        check=False,
    )
    sys.exit(result.returncode)


def cmd_list_groups() -> None:
    if not SPEC_FILE.is_file():
        err("Error: No cached spec found. Run 'ensure-spec' first.")
        sys.exit(1)
    ensure_jq()
    expr = (
        '[.paths | to_entries[] | .key as $path | .value | to_entries[] '
        '| select(.key == "parameters" | not) '
        '| {group: ($path | split("/")[1]), method: .key}] '
        '| group_by(.group) '
        '| map({group: .[0].group, operations: length}) '
        '| sort_by(-.operations)'
    )
    result = subprocess.run(
        ["jq", expr, str(SPEC_FILE)],
        check=False,
    )
    sys.exit(result.returncode)


def cmd_status() -> None:
    print(f"Cache directory: {CACHE_DIR}")
    if SPEC_FILE.is_file():
        size = SPEC_FILE.stat().st_size
        print(f"Spec file: {SPEC_FILE} ({size} bytes)")
    else:
        print("Spec file: not downloaded")
    if CHECK_FILE.is_file():
        print(f"Last checked: {cached_date()}")
        print(f"Spec version: {cached_version()}")
    else:
        print("Last checked: never")


def usage() -> None:
    print(
        """Usage: spec-manager.py <command> [args...]

Commands:
  ensure-spec    Download spec if missing or stale (daily check)
  update-spec    Force re-download the spec
  query [args]   Run a jq expression against the cached spec
  list-groups    List all API groups with operation counts
  status         Show cache status
  help           Show this help

Query examples:
  spec-manager.py query '.info'
  spec-manager.py query --arg group "boards" \\
    '.paths | to_entries[] | select(.key | startswith("/\\($group)"))'

Environment variables:
  TRELLO_CACHE_DIR  Cache directory (default: ~/.claude/cache/trello)
  TRELLO_SPEC_URL   Base URL for the spec (default: dac-static.atlassian.com)
  TRELLO_DOCS_URL   Docs page URL for version detection"""
    )


def main() -> None:
    args = sys.argv[1:]
    cmd = args[0] if args else "help"
    rest = args[1:]

    if cmd == "ensure-spec":
        cmd_ensure_spec()
    elif cmd == "update-spec":
        cmd_update_spec()
    elif cmd == "query":
        cmd_query(rest)
    elif cmd == "list-groups":
        cmd_list_groups()
    elif cmd == "status":
        cmd_status()
    elif cmd in ("help", "--help"):
        usage()
    else:
        err(f"Unknown command: {cmd}")
        usage()
        sys.exit(1)


if __name__ == "__main__":
    main()
