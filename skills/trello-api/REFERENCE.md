# Trello API Quick Reference

Common examples by API group using the `trello.py` wrapper. Auth is handled automatically.

All commands below use the full path: `${CLAUDE_PLUGIN_ROOT}/scripts/trello.py`

## Contents
- [Boards](#boards)
- [Lists](#lists)
- [Cards](#cards)
- [Labels](#labels)
- [Checklists](#checklists)
- [Comments](#comments)
- [Attachments](#attachments)
- [Members](#members)
- [Search](#search)
- [Webhooks](#webhooks)

## Boards

```bash
# Get all boards for authenticated member
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py GET /members/me/boards

# Get a board by ID
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py GET /boards/{id}

# Create a board
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py POST /boards name=My+Board

# Update a board
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py PUT /boards/{id} name=New+Name

# Delete a board
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py DELETE /boards/{id}

# Get lists on a board
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py GET /boards/{id}/lists

# Get cards on a board
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py GET /boards/{id}/cards

# Get members of a board
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py GET /boards/{id}/members

# Get labels on a board
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py GET /boards/{id}/labels
```

## Lists

```bash
# Create a list on a board
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py POST /lists name=To+Do idBoard={boardId}

# Get a list
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py GET /lists/{id}

# Update a list (rename)
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py PUT /lists/{id} name=In+Progress

# Archive a list
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py PUT /lists/{id} closed=true

# Get cards in a list
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py GET /lists/{id}/cards
```

## Cards

```bash
# Create a card
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py POST /cards name=My+Task idList={listId}

# Create a card with description and due date
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py POST /cards name=My+Task idList={listId} desc=Task+description due=2025-12-31

# Get a card
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py GET /cards/{id}

# Update a card
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py PUT /cards/{id} name=Updated+Name desc=New+description

# Move a card to another list
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py PUT /cards/{id} idList={newListId}

# Add a label to a card
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py POST /cards/{id}/idLabels value={labelId}

# Delete a card
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py DELETE /cards/{id}
```

## Labels

```bash
# Create a label on a board
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py POST /labels name=Bug color=red idBoard={boardId}

# Get a label
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py GET /labels/{id}

# Update a label
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py PUT /labels/{id} name=Feature color=green

# Delete a label
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py DELETE /labels/{id}
```

Available label colors: `green`, `yellow`, `orange`, `red`, `purple`, `blue`, `sky`, `lime`, `pink`, `black`, `null` (no color).

## Checklists

```bash
# Create a checklist on a card
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py POST /checklists idCard={cardId} name=Tasks

# Get checklists on a card
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py GET /cards/{cardId}/checklists

# Add an item to a checklist
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py POST /checklists/{checklistId}/checkItems name=Sub+task

# Mark checklist item complete
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py PUT /cards/{cardId}/checkItem/{checkItemId} state=complete

# Mark checklist item incomplete
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py PUT /cards/{cardId}/checkItem/{checkItemId} state=incomplete

# Delete a checklist
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py DELETE /checklists/{id}
```

## Comments

```bash
# Add a comment to a card
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py POST /cards/{cardId}/actions/comments text=My+comment

# Get comments on a card (actions filtered to commentCard type)
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py GET /cards/{cardId}/actions filter=commentCard
```

## Attachments

```bash
# List attachments on a card
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py GET /cards/{cardId}/attachments

# Attach a URL to a card
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py POST /cards/{cardId}/attachments url=https://example.com name=Link

# Upload a file attachment
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py POST /cards/{cardId}/attachments file=@/path/to/file.pdf name=document.pdf

# Delete an attachment
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py DELETE /cards/{cardId}/attachments/{attachmentId}
```

## Members

```bash
# Get current member (me)
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py GET /members/me

# Get a member by ID or username
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py GET /members/{idOrUsername}

# Get boards for a member
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py GET /members/{id}/boards

# Get cards assigned to a member
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py GET /members/{id}/cards
```

## Search

```bash
# Search for cards and boards
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py GET /search query=my+search+term

# Search with filters (cards only, limit results)
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py GET /search query=bug modelTypes=cards cards_limit=10

# Search within a specific board
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py GET /search query=bug idBoards={boardId}
```

## Webhooks

```bash
# Create a webhook
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py POST /webhooks callbackURL=https://example.com/webhook idModel={boardOrCardId} description=My+webhook

# List webhooks for current token
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py GET /tokens/${TRELLO_TOKEN}/webhooks

# Delete a webhook
${CLAUDE_PLUGIN_ROOT}/scripts/trello.py DELETE /webhooks/{id}
```
