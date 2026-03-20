---
name: trello
description: "Manage Trello boards, lists, and cards with short-lived okoro tokens."
tags: [productivity, ai, project-management, task-management, kanban]
version: 2.0.0
repo: okoroai/okoro-trello
---

# trello

Give your AI agent full Trello access — create tasks, move cards, sync board state — without exposing raw Trello credentials to your agent environment.

All API calls go through the [okoro proxy](https://okoro.ai), which signs requests with OAuth 1.0a, enforces permission scopes, and writes an audit trail for every action your agent takes.

## Requirements

| Variable | Description |
|---|---|
| `OKORO_SERVICE_TOKEN` | Service token from the [okoro dashboard](https://hub.okoro.ai/docs/get-token) (`svc_...`) |

[How to get your token →](https://hub.okoro.ai/docs/get-token)

## How it works

Rather than giving your agent raw Trello credentials, you configure a **service token** once. When the skill runs, it exchanges that token for a short-lived **operation token** scoped to exactly the action being performed. The okoro proxy signs the request, forwards it to Trello, and records the intent in an audit log.

Your Trello credentials never touch your agent environment. [Learn more about how okoro works →](https://okoro.ai/how-it-works)

## What your agent can do

- **Read** boards, lists, and cards
- **Create** cards and status columns
- **Update** card titles, descriptions, due dates, and assignees
- **Move** cards between columns
- **Delete** cards
