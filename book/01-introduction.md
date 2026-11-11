# 1. Introduction

## What this book is

This is the complete technical documentation for **Korvexa**, a self-hostable,
Jira-style task manager. It documents the entire codebase: the FastAPI backend,
the Flutter frontend, the database schema and migrations, the test suite, and
how to run and deploy the whole thing.

The goal is that you can read this book without ever having seen the project,
and come away able to:

- run the app locally and point it at any supported database;
- understand how a request flows from the Flutter UI through the API to the
  database and back;
- find and modify any feature with confidence about what it touches;
- re-implement any part of the system from the explanations here.

## Who it's for

- **New developers** joining the project, who need to get productive fast.
- **Self-hosters** who want to deploy and operate Korvexa.
- **Learners** using this as a worked example of a production-shaped
  FastAPI + Flutter application with real auth, multi-tenancy, and tests.

You should be comfortable reading Python and Dart. You don't need prior FastAPI,
SQLModel, or Flutter experience — the relevant concepts are explained where they
first appear.

## How the book is organized

The book has four parts:

- **Part I — Orientation** (chapters 1–4): the big picture and how to get the
  app running.
- **Part II — Backend deep dive** (chapters 5–10): the FastAPI application, one
  chapter per major concern.
- **Part III — Frontend deep dive** (chapters 11–13): the Flutter application.
- **Part IV — Reference** (chapters 14–21): API, configuration, testing,
  deployment, security, troubleshooting, glossary, and appendix.

Each deep-dive chapter follows the same shape: what the module is for, how it
fits into the whole, the key functions/classes with short annotated code
excerpts, and a diagram where it clarifies a flow.

## A note on accuracy

Everything in this book is derived from the actual source code. Code excerpts
are trimmed for focus — open the linked file to see the full context. Where the
book states an intended behavior that isn't fully enforced by the code, it says
so explicitly (look for **Note** and **Caveat** callouts).

## The "phases" you'll see referenced

Korvexa was built in five increments, each a single git commit. Understanding
them helps explain why the code is shaped the way it is — especially the
single "team-later seam" (see [Chapter 3](03-architecture.md) and
[Chapter 7](07-auth-and-multitenancy.md)) that let a single-user app become a
multi-tenant team app by changing one file.

| Phase | Theme | What landed |
|-------|-------|-------------|
| 0 | Scaffolding | Repo layout, Alembic, `/health`, pytest, Flutter boot |
| 1 | Core MVP (single user) | Projects, tasks, board, "upcoming" |
| 2 | Depth & polish | Comments, labels, search/filter, reorder, activity, archive, pagination |
| 3 | Teams & auth | JWT auth, multi-workspace, invites, roles, assignees, notifications |
| 4 | Hardening & ship | Error envelope, request-id logging, rate limiting, Docker, deploy notes |

The full timeline is in the [Appendix](21-appendix.md#version-history).

---

Next: [Chapter 2 — Project Overview](02-project-overview.md)
