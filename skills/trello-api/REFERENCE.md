# Trello API Quick Reference

Common curl examples by API group. All commands require auth params: `key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}`

Base URL: `https://api.trello.com/1`

**Important:** Always write curl output to a temp file, then parse with jq. Do not pipe curl directly to jq.

```bash
# Pattern: curl to file, then jq
curl -s -o /tmp/trello-response.json "URL"
jq . /tmp/trello-response.json
```

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
curl -s -o /tmp/trello-response.json "https://api.trello.com/1/members/me/boards?key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json

# Get a board by ID
curl -s -o /tmp/trello-response.json "https://api.trello.com/1/boards/{id}?key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json

# Create a board
curl -s -o /tmp/trello-response.json -X POST "https://api.trello.com/1/boards?name=My+Board&key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json

# Update a board
curl -s -o /tmp/trello-response.json -X PUT "https://api.trello.com/1/boards/{id}?name=New+Name&key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json

# Delete a board
curl -s -o /tmp/trello-response.json -X DELETE "https://api.trello.com/1/boards/{id}?key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json

# Get lists on a board
curl -s -o /tmp/trello-response.json "https://api.trello.com/1/boards/{id}/lists?key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json

# Get cards on a board
curl -s -o /tmp/trello-response.json "https://api.trello.com/1/boards/{id}/cards?key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json

# Get members of a board
curl -s -o /tmp/trello-response.json "https://api.trello.com/1/boards/{id}/members?key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json

# Get labels on a board
curl -s -o /tmp/trello-response.json "https://api.trello.com/1/boards/{id}/labels?key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json
```

## Lists

```bash
# Create a list on a board
curl -s -o /tmp/trello-response.json -X POST "https://api.trello.com/1/lists?name=To+Do&idBoard={boardId}&key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json

# Get a list
curl -s -o /tmp/trello-response.json "https://api.trello.com/1/lists/{id}?key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json

# Update a list (rename)
curl -s -o /tmp/trello-response.json -X PUT "https://api.trello.com/1/lists/{id}?name=In+Progress&key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json

# Archive a list
curl -s -o /tmp/trello-response.json -X PUT "https://api.trello.com/1/lists/{id}?closed=true&key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json

# Get cards in a list
curl -s -o /tmp/trello-response.json "https://api.trello.com/1/lists/{id}/cards?key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json
```

## Cards

```bash
# Create a card
curl -s -o /tmp/trello-response.json -X POST "https://api.trello.com/1/cards?name=My+Task&idList={listId}&key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json

# Create a card with description and due date
curl -s -o /tmp/trello-response.json -X POST "https://api.trello.com/1/cards?name=My+Task&idList={listId}&desc=Task+description&due=2025-12-31&key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json

# Get a card
curl -s -o /tmp/trello-response.json "https://api.trello.com/1/cards/{id}?key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json

# Update a card
curl -s -o /tmp/trello-response.json -X PUT "https://api.trello.com/1/cards/{id}?name=Updated+Name&desc=New+description&key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json

# Move a card to another list
curl -s -o /tmp/trello-response.json -X PUT "https://api.trello.com/1/cards/{id}?idList={newListId}&key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json

# Add a label to a card
curl -s -o /tmp/trello-response.json -X POST "https://api.trello.com/1/cards/{id}/idLabels?value={labelId}&key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json

# Delete a card
curl -s -o /tmp/trello-response.json -X DELETE "https://api.trello.com/1/cards/{id}?key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json
```

## Labels

```bash
# Create a label on a board
curl -s -o /tmp/trello-response.json -X POST "https://api.trello.com/1/labels?name=Bug&color=red&idBoard={boardId}&key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json

# Get a label
curl -s -o /tmp/trello-response.json "https://api.trello.com/1/labels/{id}?key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json

# Update a label
curl -s -o /tmp/trello-response.json -X PUT "https://api.trello.com/1/labels/{id}?name=Feature&color=green&key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json

# Delete a label
curl -s -o /tmp/trello-response.json -X DELETE "https://api.trello.com/1/labels/{id}?key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json
```

Available label colors: `green`, `yellow`, `orange`, `red`, `purple`, `blue`, `sky`, `lime`, `pink`, `black`, `null` (no color).

## Checklists

```bash
# Create a checklist on a card
curl -s -o /tmp/trello-response.json -X POST "https://api.trello.com/1/checklists?idCard={cardId}&name=Tasks&key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json

# Get checklists on a card
curl -s -o /tmp/trello-response.json "https://api.trello.com/1/cards/{cardId}/checklists?key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json

# Add an item to a checklist
curl -s -o /tmp/trello-response.json -X POST "https://api.trello.com/1/checklists/{checklistId}/checkItems?name=Sub+task&key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json

# Mark checklist item complete
curl -s -o /tmp/trello-response.json -X PUT "https://api.trello.com/1/cards/{cardId}/checkItem/{checkItemId}?state=complete&key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json

# Mark checklist item incomplete
curl -s -o /tmp/trello-response.json -X PUT "https://api.trello.com/1/cards/{cardId}/checkItem/{checkItemId}?state=incomplete&key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json

# Delete a checklist
curl -s -o /tmp/trello-response.json -X DELETE "https://api.trello.com/1/checklists/{id}?key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json
```

## Comments

```bash
# Add a comment to a card
curl -s -o /tmp/trello-response.json -X POST "https://api.trello.com/1/cards/{cardId}/actions/comments?text=My+comment&key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json

# Get comments on a card (actions filtered to commentCard type)
curl -s -o /tmp/trello-response.json "https://api.trello.com/1/cards/{cardId}/actions?filter=commentCard&key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json
```

## Attachments

```bash
# List attachments on a card
curl -s -o /tmp/trello-response.json "https://api.trello.com/1/cards/{cardId}/attachments?key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json

# Attach a URL to a card
curl -s -o /tmp/trello-response.json -X POST "https://api.trello.com/1/cards/{cardId}/attachments?url=https://example.com&name=Link&key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json

# Upload a file attachment
curl -s -o /tmp/trello-response.json -X POST "https://api.trello.com/1/cards/{cardId}/attachments?key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}" \
  -F "file=@/path/to/file.pdf" -F "name=document.pdf"
jq . /tmp/trello-response.json

# Delete an attachment
curl -s -o /tmp/trello-response.json -X DELETE "https://api.trello.com/1/cards/{cardId}/attachments/{attachmentId}?key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json
```

## Members

```bash
# Get current member (me)
curl -s -o /tmp/trello-response.json "https://api.trello.com/1/members/me?key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json

# Get a member by ID or username
curl -s -o /tmp/trello-response.json "https://api.trello.com/1/members/{idOrUsername}?key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json

# Get boards for a member
curl -s -o /tmp/trello-response.json "https://api.trello.com/1/members/{id}/boards?key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json

# Get cards assigned to a member
curl -s -o /tmp/trello-response.json "https://api.trello.com/1/members/{id}/cards?key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json
```

## Search

```bash
# Search for cards and boards
curl -s -o /tmp/trello-response.json "https://api.trello.com/1/search?query=my+search+term&key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json

# Search with filters (cards only, limit results)
curl -s -o /tmp/trello-response.json "https://api.trello.com/1/search?query=bug&modelTypes=cards&cards_limit=10&key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json

# Search within a specific board
curl -s -o /tmp/trello-response.json "https://api.trello.com/1/search?query=bug&idBoards={boardId}&key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json
```

## Webhooks

```bash
# Create a webhook
curl -s -o /tmp/trello-response.json -X POST "https://api.trello.com/1/webhooks?callbackURL=https://example.com/webhook&idModel={boardOrCardId}&description=My+webhook&key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json

# List webhooks for current token
curl -s -o /tmp/trello-response.json "https://api.trello.com/1/tokens/${TRELLO_TOKEN}/webhooks?key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json

# Delete a webhook
curl -s -o /tmp/trello-response.json -X DELETE "https://api.trello.com/1/webhooks/{id}?key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}"
jq . /tmp/trello-response.json
```
