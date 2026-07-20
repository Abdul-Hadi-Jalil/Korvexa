def _make_task(client, status="todo"):
    project = client.post("/projects", json={"name": "Alpha"}).json()
    task = client.post(
        f"/projects/{project['id']}/tasks", json={"title": "T1", "status": status}
    ).json()
    return project, task


def test_create_and_list_label(client):
    resp = client.post("/labels", json={"name": "bug", "color": "#ff0000"})
    assert resp.status_code == 201
    assert resp.json()["name"] == "bug"

    listed = client.get("/labels").json()
    assert [l["name"] for l in listed] == ["bug"]


def test_label_name_unique_per_workspace(client):
    client.post("/labels", json={"name": "bug"})
    resp = client.post("/labels", json={"name": "bug"})
    assert resp.status_code == 409


def test_label_requires_name(client):
    assert client.post("/labels", json={"name": ""}).status_code == 422


def test_update_label(client):
    label = client.post("/labels", json={"name": "bug"}).json()
    resp = client.patch(f"/labels/{label['id']}", json={"name": "defect", "color": "#000"})
    assert resp.status_code == 200
    assert resp.json()["name"] == "defect"


def test_update_label_name_conflict(client):
    client.post("/labels", json={"name": "bug"})
    other = client.post("/labels", json={"name": "chore"}).json()
    resp = client.patch(f"/labels/{other['id']}", json={"name": "bug"})
    assert resp.status_code == 409


def test_delete_label(client):
    label = client.post("/labels", json={"name": "bug"}).json()
    assert client.delete(f"/labels/{label['id']}").status_code == 204
    assert client.get("/labels").json() == []


def test_assign_labels_to_task(client):
    _project, task = _make_task(client)
    bug = client.post("/labels", json={"name": "bug"}).json()
    urgent = client.post("/labels", json={"name": "urgent"}).json()

    resp = client.put(f"/tasks/{task['id']}/labels", json=[bug["id"], urgent["id"]])
    assert resp.status_code == 200
    names = {l["name"] for l in resp.json()["labels"]}
    assert names == {"bug", "urgent"}


def test_assign_labels_replaces_set(client):
    _project, task = _make_task(client)
    bug = client.post("/labels", json={"name": "bug"}).json()
    urgent = client.post("/labels", json={"name": "urgent"}).json()

    client.put(f"/tasks/{task['id']}/labels", json=[bug["id"], urgent["id"]])
    resp = client.put(f"/tasks/{task['id']}/labels", json=[bug["id"]])
    names = {l["name"] for l in resp.json()["labels"]}
    assert names == {"bug"}


def test_assign_unknown_label_rejected(client):
    _project, task = _make_task(client)
    resp = client.put(f"/tasks/{task['id']}/labels", json=[9999])
    assert resp.status_code == 400


def test_create_task_with_labels(client):
    project = client.post("/projects", json={"name": "Alpha"}).json()
    bug = client.post("/labels", json={"name": "bug"}).json()
    resp = client.post(
        f"/projects/{project['id']}/tasks", json={"title": "T", "label_ids": [bug["id"]]}
    )
    assert resp.status_code == 201
    assert [l["name"] for l in resp.json()["labels"]] == ["bug"]


def test_filter_board_by_label(client):
    project = client.post("/projects", json={"name": "Alpha"}).json()
    bug = client.post("/labels", json={"name": "bug"}).json()
    tagged = client.post(
        f"/projects/{project['id']}/tasks", json={"title": "Tagged", "label_ids": [bug["id"]]}
    ).json()
    client.post(f"/projects/{project['id']}/tasks", json={"title": "Untagged"})

    board = client.get(f"/projects/{project['id']}/board", params={"label_id": bug["id"]}).json()
    all_tasks = [t for column in board.values() for t in column]
    assert [t["id"] for t in all_tasks] == [tagged["id"]]


def test_deleting_label_removes_it_from_tasks(client):
    _project, task = _make_task(client)
    bug = client.post("/labels", json={"name": "bug"}).json()
    client.put(f"/tasks/{task['id']}/labels", json=[bug["id"]])

    client.delete(f"/labels/{bug['id']}")
    refreshed = client.get(f"/tasks/{task['id']}").json()
    assert refreshed["labels"] == []
