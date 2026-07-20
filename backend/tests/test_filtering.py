from datetime import date, timedelta


def _make_project(client):
    return client.post("/projects", json={"name": "Alpha"}).json()


def test_search_by_title(client):
    project = _make_project(client)
    client.post(f"/projects/{project['id']}/tasks", json={"title": "Fix login bug"})
    client.post(f"/projects/{project['id']}/tasks", json={"title": "Write docs"})

    page = client.get(f"/projects/{project['id']}/tasks", params={"q": "login"}).json()
    assert page["total"] == 1
    assert page["items"][0]["title"] == "Fix login bug"


def test_search_by_description(client):
    project = _make_project(client)
    client.post(
        f"/projects/{project['id']}/tasks",
        json={"title": "Task A", "description": "involves the payment flow"},
    )
    client.post(f"/projects/{project['id']}/tasks", json={"title": "Task B"})

    page = client.get(f"/projects/{project['id']}/tasks", params={"q": "payment"}).json()
    assert page["total"] == 1
    assert page["items"][0]["title"] == "Task A"


def test_filter_by_status(client):
    project = _make_project(client)
    client.post(f"/projects/{project['id']}/tasks", json={"title": "A", "status": "todo"})
    client.post(f"/projects/{project['id']}/tasks", json={"title": "B", "status": "done"})

    page = client.get(f"/projects/{project['id']}/tasks", params={"status": "done"}).json()
    assert [t["title"] for t in page["items"]] == ["B"]


def test_filter_by_priority(client):
    project = _make_project(client)
    client.post(f"/projects/{project['id']}/tasks", json={"title": "A", "priority": "high"})
    client.post(f"/projects/{project['id']}/tasks", json={"title": "B", "priority": "low"})

    page = client.get(f"/projects/{project['id']}/tasks", params={"priority": "high"}).json()
    assert [t["title"] for t in page["items"]] == ["A"]


def test_filter_by_due_overdue(client):
    project = _make_project(client)
    today = date.today()
    client.post(
        f"/projects/{project['id']}/tasks",
        json={"title": "Overdue", "due_date": str(today - timedelta(days=1))},
    )
    client.post(
        f"/projects/{project['id']}/tasks",
        json={"title": "Future", "due_date": str(today + timedelta(days=10))},
    )

    page = client.get(f"/projects/{project['id']}/tasks", params={"due": "overdue"}).json()
    assert [t["title"] for t in page["items"]] == ["Overdue"]


def test_tasks_pagination(client):
    project = _make_project(client)
    for i in range(5):
        client.post(f"/projects/{project['id']}/tasks", json={"title": f"T{i}"})

    page = client.get(f"/projects/{project['id']}/tasks", params={"limit": 2, "offset": 0}).json()
    assert page["total"] == 5
    assert len(page["items"]) == 2


def test_combined_filters(client):
    project = _make_project(client)
    client.post(
        f"/projects/{project['id']}/tasks",
        json={"title": "urgent bug", "priority": "high", "status": "todo"},
    )
    client.post(
        f"/projects/{project['id']}/tasks",
        json={"title": "urgent chore", "priority": "low", "status": "todo"},
    )

    page = client.get(
        f"/projects/{project['id']}/tasks",
        params={"q": "urgent", "priority": "high"},
    ).json()
    assert page["total"] == 1
    assert page["items"][0]["title"] == "urgent bug"
