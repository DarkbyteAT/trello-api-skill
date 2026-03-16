# trello-api

A Claude Code plugin that gives Claude access to the entire Trello REST API (256 operations across 18 API groups) using `curl`. The official OpenAPI spec is cached locally and queried on-demand with `jq`, so Claude can discover and invoke any endpoint without loading the full spec into context.

## Prerequisites

- `curl` and `jq` installed
- Trello API credentials set as environment variables:

```bash
export TRELLO_API_KEY="your-api-key"
export TRELLO_TOKEN="your-api-token"
```

Get your credentials at [trello.com/power-ups/admin](https://trello.com/power-ups/admin):
1. Select your Power-Up (or create one)
2. Copy the **API Key**
3. Generate a **Token** using the link on the API key page

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
3. Construct and execute the `curl` command with your credentials

### Examples

- "Show my Trello boards"
- "Create a new Trello board called Project Alpha"
- "Search for cards mentioning 'bug' on Trello"
- "Set up a webhook for my Trello board"
- "Add a label to this Trello card"

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

The plugin bundles a `spec-manager.sh` script that:

- **Caches** the Trello OpenAPI spec at `~/.claude/cache/trello/swagger.v3.json`
- **Checks daily** for spec version updates on the Atlassian docs site
- **Queries** the spec with `jq` to extract only the relevant endpoints, parameters, and schemas
- Claude then uses the query results to construct precise `curl` commands

This means Claude has access to the full Trello API without any of the spec consuming conversation context until needed.

## License

MIT
