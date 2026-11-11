"""Tests for GET /me/calendar?start=&end=."""
from datetime import date, timedelta


def _project(client):
    return client.post("/projects", json={"name": "Alpha"}).json()


def _task(client, project_id, **kwargs):
    payload = {"title": "T"}
    payload.update(kwargs)
    return client.post(f"/projects/{project_id}/tasks", json=payload).json()


def test_calendar_requires_auth(raw_client):
    assert raw_client.get("/me/calendar", params={"start": "2026-01-01", "end": "2026-01-31"}).status_code == 401


def test_calendar_returns_tasks_in_range(client):
    project = _project(client)
    today = date.today()
    _task(client, project["id"], title="InRange", due_date=str(today))
    _task(client, project["id"], title="Outside", due_date=str(today + timedelta(days=60)))
    _task(client, project["id"], title="NoDue")  # no due date

    start = str(today - timedelta(days=5))
    end = str(today + timedelta(days=5))
    tasks = client.get("/me/calendar", params={"start": start, "end": end}).json()
    titles = {t["title"] for t in tasks}
    assert titles == {"InRange"}


def test_calendar_includes_all_statuses(client):
    project = _project(client)
    today = date.today()
    done = _task(client, project["id"], title="DoneTask", due_date=str(today))
    client.patch(f"/tasks/{done['id']}", json={"status": "done"})

    tasks = client.get(
        "/me/calendar",
        params={"start": str(today), "end": str(today)},
    ).json()
    assert {t["title"] for t in tasks} == {"DoneTask"}
    assert tasks[0]["project_name"] == "Alpha"


def test_calendar_invalid_date_rejected(client):
    resp = client.get("/me/calendar", params={"start": "not-a-date", "end": "2026-01-31"})
    assert resp.status_code == 422


def test_calendar_scoped_to_workspace(client, register_client):
    bob = register_client("bob@example.com", "Bob")
    today = date.today()
    bob_project = client.post("/projects", json={"name": "BobProj"}, headers=bob["headers"]).json()
    client.post(
        f"/projects/{bob_project['id']}/tasks",
        json={"title": "Secret", "due_date": str(today)},
        headers=bob["headers"],
    )

    tasks = client.get("/me/calendar", params={"start": str(today), "end": str(today)}).json()
    assert tasks == []
