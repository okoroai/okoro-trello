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
- **intent** — the session intent: the user's overall goal for this conversation (not a description of the API call)
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
| Update card | PUT | `/cards/<card_id>` · `{"name":"…","idList":"…","due":"…","pos":"…","closed":false,"dueComplete":false}` |
| Move card | PUT | `/cards/<card_id>` · `{"idList":"<target_list_id>"}` |
| Archive card | PUT | `/cards/<card_id>` · `{"closed":true}` |
| Delete card | DELETE | `/cards/<card_id>` |

## Token & scope

`OKORO_SERVICE_TOKEN` must have at least the required scope level:
`read` < `write` < `update` < `delete`

The proxy returns HTTP 403 if the token's configured scope is insufficient.

## Intent

`--intent` is the **session intent** — the user's overall goal for this conversation, not a description of the individual API call. It is logged by the proxy as the audit reason for every token issued in this session. Pass the same value for every call you make within a single user request.

```
--intent "review this week's Okoro board"   ✓  (why the user asked)
--intent "get /boards/<id>/lists"           ✗  (describes the API call)
--intent "fetch board data"                 ✗  (too vague, still call-level)
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
