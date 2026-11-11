"""Tests for GET /dashboard (workspace aggregate stats)."""


def _project(client, name="Alpha"):
    return client.post("/projects", json={"name": name}).json()


def _task(client, project_id, **kwargs):
    payload = {"title": "T"}
    payload.update(kwargs)
    return client.post(f"/projects/{project_id}/tasks", json=payload).json()


def test_dashboard_requires_auth(raw_client):
    assert raw_client.get("/dashboard").status_code == 401


def test_dashboard_empty(client):
    stats = client.get("/dashboard").json()
    assert stats["projects_active"] == 0
    assert stats["tasks_total"] == 0


def test_dashboard_counts(client):
    from datetime import date, timedelta

    project = _project(client)
    _task(client, project["id"], status="todo", priority="high")
    _task(client, project["id"], status="in_progress", priority="medium")
    done = _task(client, project["id"], status="todo")
    client.patch(f"/tasks/{done['id']}", json={"status": "done"})
    _task(client, project["id"], due_date=str(date.today() - timedelta(days=1)))  # overdue

    stats = client.get("/dashboard").json()
    assert stats["projects_active"] == 1
    assert stats["tasks_total"] == 4
    assert stats["tasks_done"] == 1
    assert stats["tasks_in_progress"] == 1
    assert stats["tasks_overdue"] == 1
    assert stats["priority_high"] == 1


def test_dashboard_assigned_to_me(client):
    project = _project(client)
    owner_id = client.auth_context["workspace_id"] and _owner_id(client)
    _task(client, project["id"], assignee_id=owner_id)
    _task(client, project["id"])  # unassigned

    stats = client.get("/dashboard").json()
    assert stats["assigned_to_me_open"] == 1


def test_dashboard_excludes_archived_projects(client):
    project = _project(client)
    _task(client, project["id"])
    client.post(f"/projects/{project['id']}/archive")

    stats = client.get("/dashboard").json()
    assert stats["projects_active"] == 0
    assert stats["projects_archived"] == 1
    assert stats["tasks_total"] == 0


def test_dashboard_scoped_to_workspace(client, register_client):
    # Bob's own workspace tasks must not appear in our stats.
    bob = register_client("bob@example.com", "Bob")
    bob_project = client.post("/projects", json={"name": "BobProj"}, headers=bob["headers"]).json()
    client.post(f"/projects/{bob_project['id']}/tasks", json={"title": "Secret"}, headers=bob["headers"])

    stats = client.get("/dashboard").json()
    assert stats["tasks_total"] == 0


def _owner_id(client):
    workspace_id = client.auth_context["workspace_id"]
    members = client.get(f"/workspaces/{workspace_id}/members").json()
    return next(m["user_id"] for m in members if m["email"] == "owner@example.com")
