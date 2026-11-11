# The Korvexa Book

A complete technical guide to the Korvexa codebase — a self-hostable,
Jira-style task manager built with a FastAPI backend and a Flutter frontend.

This book is written so that a developer who has never seen the project can
read it front to back and understand — and re-implement — every part of the
system: its architecture, data model, API, frontend, tests, and deployment.

## How to read it

- **New to the project?** Read chapters 1–4 in order, then dip into the deep
  dives (5–13) for whatever you're working on.
- **Looking something up?** Jump straight to the reference chapters (14–15),
  the [Appendix](21-appendix.md), or the [Glossary](20-glossary.md).
- **Diagrams** are written in [Mermaid](https://mermaid.js.org/) and render
  directly on GitHub and in most Markdown viewers.

## Table of contents

### Part I — Orientation
1. [Introduction](01-introduction.md) — what this book is, who it's for
2. [Project Overview](02-project-overview.md) — what Korvexa does, features, tech stack
3. [Architecture](03-architecture.md) — system design, components, request lifecycle
4. [Getting Started](04-getting-started.md) — install, configure, first run

### Part II — Backend deep dive
5. [Backend Foundation](05-backend-foundation.md) — app entry, config, DB, logging, errors, rate limiting
6. [Data Model & Migrations](06-data-model-and-migrations.md) — SQLModel tables, Alembic, ER diagram
7. [Authentication & Multi-Tenancy](07-auth-and-multitenancy.md) — JWT, the workspace seam, roles, invites
8. [Projects, Tasks & the Board](08-projects-tasks-board.md) — core domain, keys, positions, board, "My Tasks"
9. [Comments, Labels & Activity](09-comments-labels-activity.md) — collaboration and the audit log
10. [Assignments & Notifications](10-assignments-notifications.md) — assignees, in-app notifications, @mentions

### Part III — Frontend deep dive
11. [Frontend Architecture](11-frontend-architecture.md) — bootstrap, session, API client, token refresh
12. [Frontend Models, Services & State](12-frontend-models-services-state.md) — data layer and providers
13. [Frontend Screens & Widgets](13-frontend-screens-widgets.md) — the UI and navigation

### Part IV — Reference
14. [API Reference](14-api-reference.md) — every endpoint
15. [Configuration Reference](15-configuration-reference.md) — every setting
16. [Testing](16-testing.md) — how tests are organized and run
17. [Deployment](17-deployment.md) — Docker, Fly/Railway/Render, Supabase, Flutter builds
18. [Security Considerations](18-security.md) — auth model, secrets, tenancy
19. [Troubleshooting & FAQ](19-troubleshooting-faq.md) — common problems
20. [Glossary](20-glossary.md) — terms and acronyms
21. [Appendix](21-appendix.md) — file tree, dependencies, CLI cheat sheet, version history

## Conventions used in this book

- File references look like [`backend/app/main.py`](../backend/app/main.py) and
  link to the real file in the repository.
- Code excerpts are **illustrative slices**, not full file dumps; open the
  linked file to see everything in context.
- "Phase 0–4" refers to the project's build history — one git commit per phase.
  See the [Appendix](21-appendix.md#version-history) for the timeline.
