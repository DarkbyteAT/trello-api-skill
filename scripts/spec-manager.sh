#!/usr/bin/env bash
set -euo pipefail

# Trello OpenAPI Spec Manager
# Downloads, caches, and queries the Trello REST API OpenAPI spec.

CACHE_DIR="${TRELLO_CACHE_DIR:-$HOME/.claude/cache/trello}"
SPEC_FILE="$CACHE_DIR/swagger.v3.json"
CHECK_FILE="$CACHE_DIR/.last-checked"
SPEC_BASE_URL="${TRELLO_SPEC_URL:-https://dac-static.atlassian.com/cloud/trello/swagger.v3.json}"
DOCS_URL="${TRELLO_DOCS_URL:-https://developer.atlassian.com/cloud/trello/rest/api-group-actions/}"

ensure_deps() {
  for cmd in curl jq; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "Error: '$cmd' is required but not installed." >&2
      exit 1
    fi
  done
}

ensure_cache_dir() {
  mkdir -p "$CACHE_DIR"
}

# Fetch the current _v= version from the docs page
fetch_remote_version() {
  local page
  page=$(curl -sL "$DOCS_URL" 2>/dev/null || echo "")
  if [[ -z "$page" ]]; then
    echo ""
    return
  fi
  # Extract _v=X.Y.Z from swagger.v3.json URL
  echo "$page" | grep -oE '_v=[0-9]+\.[0-9]+\.[0-9]+' | head -1 | sed 's/_v=//'
}

# Read cached version from .last-checked
cached_version() {
  if [[ -f "$CHECK_FILE" ]]; then
    sed -n '2p' "$CHECK_FILE"
  else
    echo ""
  fi
}

# Read cached check date from .last-checked
cached_date() {
  if [[ -f "$CHECK_FILE" ]]; then
    sed -n '1p' "$CHECK_FILE"
  else
    echo ""
  fi
}

download_spec() {
  local version="$1"
  local url="$SPEC_BASE_URL"
  if [[ -n "$version" ]]; then
    url="${SPEC_BASE_URL}?_v=${version}"
  fi
  echo "Downloading Trello OpenAPI spec..." >&2
  if curl -sL "$url" -o "$SPEC_FILE"; then
    echo "Spec saved to $SPEC_FILE" >&2
  else
    echo "Error: Failed to download spec from $url" >&2
    exit 1
  fi
}

write_check_file() {
  local version="$1"
  local today
  today=$(date +%Y-%m-%d)
  printf '%s\n%s\n' "$today" "$version" > "$CHECK_FILE"
}

# ensure-spec: Download spec if missing or stale (once per day)
cmd_ensure_spec() {
  ensure_cache_dir

  local today
  today=$(date +%Y-%m-%d)
  local last_date
  last_date=$(cached_date)

  # If already checked today and spec file exists, skip
  if [[ "$last_date" == "$today" && -f "$SPEC_FILE" ]]; then
    echo "Spec is up to date (checked today)." >&2
    return 0
  fi

  # Check remote version
  local remote_version
  remote_version=$(fetch_remote_version)
  local local_version
  local_version=$(cached_version)

  if [[ -n "$remote_version" && "$remote_version" == "$local_version" && -f "$SPEC_FILE" ]]; then
    # Same version, just update the date
    echo "Spec version unchanged ($remote_version), updating check date." >&2
    write_check_file "$remote_version"
    return 0
  fi

  # Download (new version or first time)
  local dl_version="${remote_version:-unknown}"
  download_spec "$remote_version"
  write_check_file "$dl_version"
}

# update-spec: Force re-download regardless of cache
cmd_update_spec() {
  ensure_cache_dir
  local remote_version
  remote_version=$(fetch_remote_version)
  local dl_version="${remote_version:-unknown}"
  download_spec "$remote_version"
  write_check_file "$dl_version"
  echo "Spec force-updated (version: $dl_version)." >&2
}

# query: Run a jq expression against the cached spec
# Usage: spec-manager.sh query [jq-args...] <expression>
# Example: spec-manager.sh query --arg group "boards" '.paths | ...'
cmd_query() {
  if [[ ! -f "$SPEC_FILE" ]]; then
    echo "Error: No cached spec found. Run 'ensure-spec' first." >&2
    exit 1
  fi
  jq "$@" "$SPEC_FILE"
}

# list-groups: Show all API groups with operation counts
cmd_list_groups() {
  if [[ ! -f "$SPEC_FILE" ]]; then
    echo "Error: No cached spec found. Run 'ensure-spec' first." >&2
    exit 1
  fi
  jq '[.paths | to_entries[] | .key as $path | .value | to_entries[] | select(.key == "parameters" | not) | {group: ($path | split("/")[1]), method: .key}] | group_by(.group) | map({group: .[0].group, operations: length}) | sort_by(-.operations)' "$SPEC_FILE"
}

# status: Show cache status
cmd_status() {
  echo "Cache directory: $CACHE_DIR"
  if [[ -f "$SPEC_FILE" ]]; then
    local size
    size=$(wc -c < "$SPEC_FILE" | tr -d ' ')
    echo "Spec file: $SPEC_FILE ($size bytes)"
  else
    echo "Spec file: not downloaded"
  fi
  if [[ -f "$CHECK_FILE" ]]; then
    echo "Last checked: $(cached_date)"
    echo "Spec version: $(cached_version)"
  else
    echo "Last checked: never"
  fi
}

usage() {
  cat <<'EOF'
Usage: spec-manager.sh <command> [args...]

Commands:
  ensure-spec    Download spec if missing or stale (daily check)
  update-spec    Force re-download the spec
  query [args]   Run a jq expression against the cached spec
  list-groups    List all API groups with operation counts
  status         Show cache status
  help           Show this help

Query examples:
  spec-manager.sh query '.info'
  spec-manager.sh query --arg group "boards" \
    '.paths | to_entries[] | select(.key | startswith("/\($group)"))'

Environment variables:
  TRELLO_CACHE_DIR  Cache directory (default: ~/.claude/cache/trello)
  TRELLO_SPEC_URL   Base URL for the spec (default: dac-static.atlassian.com)
  TRELLO_DOCS_URL   Docs page URL for version detection
EOF
}

# Main dispatch
ensure_deps

case "${1:-help}" in
  ensure-spec)  cmd_ensure_spec ;;
  update-spec)  cmd_update_spec ;;
  query)        shift; cmd_query "$@" ;;
  list-groups)  cmd_list_groups ;;
  status)       cmd_status ;;
  help|--help)  usage ;;
  *)
    echo "Unknown command: $1" >&2
    usage >&2
    exit 1
    ;;
esac
