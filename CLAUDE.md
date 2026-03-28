# CLAUDE.md

Claude Code guidance for the trello-api-skill plugin.

@README.md

## Key Rules

- `approve-trello.sh` is security-sensitive — changes affect what gets auto-approved. Test thoroughly with both valid and malicious inputs.
- Skills reference `${CLAUDE_PLUGIN_ROOT}` for script paths — this is resolved at runtime by Claude Code. Never hardcode absolute paths.
- **ALWAYS** bump the version tag and create a GitHub release after merging changes, following Semantic Versioning conventions.
