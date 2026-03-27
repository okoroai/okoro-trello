---
name: trello
description: "Interact with Trello boards, lists, and cards through the Okoro proxy. Use when asked about board status, creating or updating tasks, moving cards between columns, or managing projects."
version: 2.0.0

# Claude Code fields
argument-hint: "--endpoint /members/me/boards --intent \"list boards\""
allowed-tools: Bash

# OpenClaw fields
metadata:
  openclaw:
    requires:
      env:
        - OKORO_SERVICE_TOKEN
      bins:
        - curl
        - jq
    primaryEnv: OKORO_SERVICE_TOKEN
    homepage: https://okoro.ai
    os:
      - darwin
      - linux
---

You have access to the Trello skill via the Okoro proxy. Use `scripts/trello.sh` for all
Trello operations. The script caches the session token and refreshes it automatically on expiry.

## Usage

```bash
skills/trello/scripts/trello.sh \
  --endpoint <path> \
  --intent   <reason> \
  [--method  GET|POST|PUT|DELETE] \
  [--scope   read|write|update|delete] \
  [--payload <json>]
```

- **endpoint** — Trello API path including query parameters, e.g. `/members/me/boards` or `/boards/<id>/cards?fields=name,idList`
- **intent** — why Claude is making this call (5–10 words, reflects the user's goal)
- **method** — defaults to `GET`; set `POST`/`PUT`/`DELETE` for mutations
- **scope** — inferred from method if omitted (`GET`→read, `POST`→write, `PUT`→update, `DELETE`→delete)
- **payload** — JSON body for POST/PUT requests only. **Never use `--payload` with GET or HEAD** — pass filters and options as query parameters in `--endpoint` instead.

## Key endpoints

| Action | Method | Endpoint |
|--------|--------|----------|
| My boards | GET | `/members/me/boards` |
| Lists on a board | GET | `/boards/<board_id>/lists` |
| Cards on a board | GET | `/boards/<board_id>/cards` |
| Cards in a list | GET | `/lists/<list_id>/cards` |
| Single card | GET | `/cards/<card_id>` |
| Create card | POST | `/cards` · `{"idList":"…","name":"…","desc":"…","pos":"bottom"}` |
| Create list | POST | `/lists` · `{"idBoard":"…","name":"…","pos":"bottom"}` |
| Update card | PUT | `/cards/<card_id>` · `{"name":"…","idList":"…","due":"…"}` |
| Move card | PUT | `/cards/<card_id>` · `{"idList":"<target_list_id>"}` |
| Delete card | DELETE | `/cards/<card_id>` |

## Token & scope

`OKORO_SERVICE_TOKEN` must have at least the required scope level:
`read` < `write` < `update` < `delete`

The proxy returns HTTP 403 if the token's configured scope is insufficient.

## Intent

Always pass `--intent` with the user's actual reason — not a description of the API call.

```
--intent "check todo items on Okoro board"   ✓
--intent "sync full Trello board snapshot"   ✗
```

## Typical workflows

**Show board status:**
```bash
# 1. Get lists (columns)
skills/trello/scripts/trello.sh --endpoint /boards/<id>/lists --intent "get board columns"
# 2. Get cards per list
skills/trello/scripts/trello.sh --endpoint /lists/<list_id>/cards --intent "get tasks in column"
```

**Create a task:**
```bash
skills/trello/scripts/trello.sh --method POST --endpoint /cards \
  --intent "create task from user request" \
  --payload '{"idList":"<list_id>","name":"Task title","desc":"Details"}'
```

**Move a card to Done:**
```bash
skills/trello/scripts/trello.sh --method PUT --endpoint /cards/<card_id> \
  --intent "mark task as done" \
  --payload '{"idList":"<done_list_id>"}'
```
