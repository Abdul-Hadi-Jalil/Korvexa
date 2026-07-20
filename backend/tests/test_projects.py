def test_create_project_derives_key_single_word(client):
    resp = client.post("/projects", json={"name": "Marketing"})
    assert resp.status_code == 201
    body = resp.json()
    assert body["key"] == "MARK"
    assert body["name"] == "Marketing"
    assert body["archived"] is False
    assert body["open_tasks"] == 0
    assert body["total_tasks"] == 0


def test_create_project_derives_key_multi_word(client):
    resp = client.post("/projects", json={"name": "Marketing Site Revamp"})
    assert resp.status_code == 201
    assert resp.json()["key"] == "MSR"


def test_create_project_explicit_key(client):
    resp = client.post("/projects", json={"name": "Acme Corp", "key": "acme"})
    assert resp.status_code == 201
    assert resp.json()["key"] == "ACME"


def test_create_project_duplicate_key_conflicts(client):
    client.post("/projects", json={"name": "Acme", "key": "ACME"})
    resp = client.post("/projects", json={"name": "Acme Two", "key": "ACME"})
    assert resp.status_code == 409


def test_create_project_derived_key_auto_deduplicates(client):
    first = client.post("/projects", json={"name": "Acme"})
    second = client.post("/projects", json={"name": "Acme"})
    assert first.json()["key"] != second.json()["key"]
    assert second.json()["key"].startswith("ACME")


def test_create_project_requires_name(client):
    resp = client.post("/projects", json={})
    assert resp.status_code == 422


def test_create_project_rejects_blank_name(client):
    resp = client.post("/projects", json={"name": ""})
    assert resp.status_code == 422


def test_list_projects(client):
    client.post("/projects", json={"name": "Alpha"})
    client.post("/projects", json={"name": "Beta"})
    resp = client.get("/projects")
    assert resp.status_code == 200
    names = {p["name"] for p in resp.json()}
    assert names == {"Alpha", "Beta"}


def test_get_project_not_found(client):
    resp = client.get("/projects/9999")
    assert resp.status_code == 404


def test_update_project(client):
    created = client.post("/projects", json={"name": "Alpha"}).json()
    resp = client.patch(f"/projects/{created['id']}", json={"description": "desc"})
    assert resp.status_code == 200
    assert resp.json()["description"] == "desc"
    assert resp.json()["name"] == "Alpha"  # untouched


def test_update_project_not_found(client):
    resp = client.patch("/projects/9999", json={"description": "x"})
    assert resp.status_code == 404


def test_update_project_rejects_blank_name(client):
    created = client.post("/projects", json={"name": "Alpha"}).json()
    resp = client.patch(f"/projects/{created['id']}", json={"name": ""})
    assert resp.status_code == 422


def test_delete_project_cascades_tasks(client):
    project = client.post("/projects", json={"name": "Alpha"}).json()
    task = client.post(f"/projects/{project['id']}/tasks", json={"title": "T1"}).json()

    resp = client.delete(f"/projects/{project['id']}")
    assert resp.status_code == 204

    assert client.get(f"/projects/{project['id']}").status_code == 404
    assert client.get(f"/tasks/{task['id']}").status_code == 404


def test_delete_project_not_found(client):
    resp = client.delete("/projects/9999")
    assert resp.status_code == 404


def test_project_task_counts(client):
    project = client.post("/projects", json={"name": "Alpha"}).json()
    t1 = client.post(f"/projects/{project['id']}/tasks", json={"title": "T1"}).json()
    client.post(f"/projects/{project['id']}/tasks", json={"title": "T2"}).json()
    client.patch(f"/tasks/{t1['id']}", json={"status": "done"})

    resp = client.get(f"/projects/{project['id']}")
    body = resp.json()
    assert body["total_tasks"] == 2
    assert body["open_tasks"] == 1
