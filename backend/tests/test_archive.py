def test_archive_hides_project_by_default(client):
    project = client.post("/projects", json={"name": "Alpha"}).json()
    resp = client.post(f"/projects/{project['id']}/archive")
    assert resp.status_code == 200
    assert resp.json()["archived"] is True

    names = {p["name"] for p in client.get("/projects").json()}
    assert "Alpha" not in names


def test_archived_project_visible_with_include_archived(client):
    project = client.post("/projects", json={"name": "Alpha"}).json()
    client.post(f"/projects/{project['id']}/archive")

    names = {p["name"] for p in client.get("/projects", params={"include_archived": True}).json()}
    assert "Alpha" in names


def test_unarchive_restores_project(client):
    project = client.post("/projects", json={"name": "Alpha"}).json()
    client.post(f"/projects/{project['id']}/archive")
    resp = client.post(f"/projects/{project['id']}/unarchive")
    assert resp.status_code == 200
    assert resp.json()["archived"] is False

    names = {p["name"] for p in client.get("/projects").json()}
    assert "Alpha" in names


def test_archive_missing_project_404(client):
    assert client.post("/projects/9999/archive").status_code == 404


def test_archived_project_still_accessible_directly(client):
    project = client.post("/projects", json={"name": "Alpha"}).json()
    client.post(f"/projects/{project['id']}/archive")
    # Archiving hides from the list but doesn't delete -- direct access works.
    assert client.get(f"/projects/{project['id']}").status_code == 200
