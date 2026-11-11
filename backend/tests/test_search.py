"""Tests for GET /search/tasks?q=."""


def _project(client, name="Alpha"):
    return client.post("/projects", json={"name": name}).json()


def test_search_requires_auth(raw_client):
    assert raw_client.get("/search/tasks", params={"q": "x"}).status_code == 401


def test_search_requires_query(client):
    assert client.get("/search/tasks").status_code == 422


def test_search_by_title_across_projects(client):
    p1 = _project(client, "Alpha")
    p2 = _project(client, "Beta")
    client.post(f"/projects/{p1['id']}/tasks", json={"title": "Fix login bug"})
    client.post(f"/projects/{p2['id']}/tasks", json={"title": "Write login docs"})
    client.post(f"/projects/{p1['id']}/tasks", json={"title": "Unrelated"})

    results = client.get("/search/tasks", params={"q": "login"}).json()
    titles = {t["title"] for t in results}
    assert titles == {"Fix login bug", "Write login docs"}
    # Results carry project info for display.
    assert all(t["project_key"] for t in results)


def test_search_by_description(client):
    project = _project(client)
    client.post(
        f"/projects/{project['id']}/tasks",
        json={"title": "Task A", "description": "touches the payment flow"},
    )
    client.post(f"/projects/{project['id']}/tasks", json={"title": "Task B"})

    results = client.get("/search/tasks", params={"q": "payment"}).json()
    assert {t["title"] for t in results} == {"Task A"}


def test_search_excludes_archived_projects(client):
    project = _project(client)
    client.post(f"/projects/{project['id']}/tasks", json={"title": "hidden gem"})
    client.post(f"/projects/{project['id']}/archive")

    assert client.get("/search/tasks", params={"q": "gem"}).json() == []


def test_search_scoped_to_workspace(client, register_client):
    bob = register_client("bob@example.com", "Bob")
    bob_project = client.post("/projects", json={"name": "BobProj"}, headers=bob["headers"]).json()
    client.post(
        f"/projects/{bob_project['id']}/tasks",
        json={"title": "secret sauce"},
        headers=bob["headers"],
    )

    assert client.get("/search/tasks", params={"q": "secret"}).json() == []
