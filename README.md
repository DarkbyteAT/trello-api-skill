# trello-api

A Claude Code plugin that gives Claude access to the entire Trello REST API (256 operations across 18 API groups) using a `trello.sh` wrapper script. The official OpenAPI spec is cached locally and queried on-demand with `jq`, so Claude can discover and invoke any endpoint without loading the full spec into context.

API calls are **auto-approved** via a bundled PreToolUse hook — no manual permission configuration needed.

## Skills

This plugin ships two skills:

| Skill | Description |
|-------|-------------|
| **trello-api** | Query and invoke any of the 256 Trello REST API operations using the `trello.sh` wrapper |
| **executing-trello-waves** | Orchestrate parallel execution of Trello implementation cards using git worktrees and subagents — identifies ready cards, analyses file conflicts, dispatches agents, reviews output, ships PRs, and manages the full Trello card lifecycle |

## Prerequisites

- `curl` and `jq` installed
- Trello API credentials set as environment variables in your shell profile
    - _Tip: Ask Claude to help with this!_

```bash
export TRELLO_API_KEY="your-api-key"
export TRELLO_TOKEN="your-api-token"
```

Get your credentials at [trello.com/power-ups/admin](https://trello.com/power-ups/admin):
1. Select your Power-Up (or create a new App for Claude Code in your workspace)
2. Copy the **API Key**
3. Generate a **Token** using the link on the API key page and authorize for your workspace

## Installation

### Via Claude Plugin Marketplace

If this plugin is available in a marketplace you've added:

```
/plugin install trello-api@<marketplace-name>
```

### Direct Install from GitHub

```
/plugin install --from https://github.com/DarkbyteAT/trello-api-skill
```

### Local Development

Clone the repo and install from the local path:

```bash
git clone https://github.com/DarkbyteAT/trello-api-skill.git
```
```
/plugin install --from /path/to/trello-api-skill
```

## Usage

Once installed, the skill activates when you mention **Trello** in conversation. Claude will:

1. Ensure the OpenAPI spec is cached and fresh
2. Look up the relevant endpoint using `jq` queries
3. Call `trello.sh` with the method, path, and parameters

All API calls go through `trello.sh`, which handles authentication, error detection, and JSON output formatting.

### Examples

- "Show my Trello boards"
- "Create a new Trello board called Project Alpha"
- "Search for cards mentioning 'bug' on Trello"
- "Set up a webhook for my Trello board"
- "Add a label to this Trello card"

### The Wrapper

`trello.sh` is a thin wrapper around `curl` that:

- Appends your `TRELLO_API_KEY` and `TRELLO_TOKEN` automatically
- Handles HTTP error detection (4xx/5xx responses)
- Outputs formatted JSON via `jq`
- Supports file uploads with `=@` syntax
- Uses temp files for safe concurrent execution

```
trello.sh <METHOD> <path> [key=value ...]
```

### Auto-Approval

The plugin bundles a `PreToolUse` hook that automatically approves calls to plugin scripts (`trello.sh` and `spec-manager.sh`). This is registered via `hooks/hooks.json` and merged into Claude Code's hook system when the plugin is enabled.

The hook includes safety checks — commands containing shell chaining operators (`&&`, `||`, `;`, etc.) are not auto-approved.

No manual permission configuration is needed. If you want to disable auto-approval, you can remove the plugin's hooks via the `/hooks` menu in Claude Code.

### Updating the Spec

The spec is checked for updates once daily. To force a refresh:

```
Ask Claude: "Update the Trello API spec"
```

Or run directly:

```bash
~/.claude/plugins/cache/trello-api/scripts/spec-manager.sh update-spec
```

## How It Works

The plugin bundles two main scripts:

- **`trello.sh`** — API wrapper that replaces raw `curl` calls. Handles auth, error detection, and JSON formatting.
- **`spec-manager.sh`** — Downloads, caches, and queries the Trello OpenAPI spec. Claude uses this to discover endpoints and parameters.

Plus a PreToolUse hook (`approve-trello.sh`) that auto-approves calls to both scripts, eliminating manual permission prompts.

This means Claude has access to the full Trello API without any of the spec consuming conversation context until needed, and without requiring manual approval for each API call.

## Contributing

Contributions are welcome — bug fixes, new features, documentation improvements, and especially help building out automated testing.

### Getting Started

1. Fork and clone the repo
2. Install your local copy as a plugin:
   ```
   /plugin install --from /path/to/trello-api-skill
   ```
3. Make sure `TRELLO_API_KEY` and `TRELLO_TOKEN` are set in your shell profile

### Project Layout

The plugin has three scripts in `scripts/`:

- **`trello.sh`** — API wrapper. Handles auth, URL-encoding, error detection, and JSON formatting.
- **`spec-manager.sh`** — Downloads, caches, and queries the Trello OpenAPI spec via `jq`.
- **`approve-trello.sh`** — PreToolUse hook that auto-approves calls to the other two scripts. Contains security checks that reject shell chaining operators while allowing safe pipes to read-only tools like `jq` and `grep`. This is the most sensitive part of the codebase — changes here affect what gets auto-approved, so take extra care.

### Testing

There's no automated test suite yet — testing is manual:

1. Install the plugin from your local clone
2. Try a range of Trello operations (create cards, search, update labels, etc.)
3. Verify the auto-approve hook accepts legitimate commands and rejects unsafe ones (e.g. commands with `&&`, `;`, or unwhitelisted pipes)
4. Test with values that contain special characters (newlines, `#`, `&`, apostrophes, backticks in Markdown) since these have been a recurring source of bugs

An automated test harness — particularly for the hook's security checks — would be a valuable contribution.

### Submitting Changes

Fork the repo, make your changes, and open a pull request. Keep PRs focused on a single concern when possible.

## License

MIT
