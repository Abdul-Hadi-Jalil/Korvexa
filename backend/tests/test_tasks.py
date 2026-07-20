def _make_project(client, name="Alpha", key=None):
    payload = {"name": name}
    if key:
        payload["key"] = key
    return client.post("/projects", json=payload).json()


def test_create_task_defaults(client):
    project = _make_project(client)
    resp = client.post(f"/projects/{project['id']}/tasks", json={"title": "First task"})
    assert resp.status_code == 201
    body = resp.json()
    assert body["title"] == "First task"
    assert body["status"] == "todo"
    assert body["priority"] == "medium"
    assert body["number"] == 1
    assert body["key"] == f"{project['key']}-1"


def test_task_numbers_increment_per_project(client):
    p1 = _make_project(client, "Alpha", "ALP")
    p2 = _make_project(client, "Beta", "BET")

    a1 = client.post(f"/projects/{p1['id']}/tasks", json={"title": "A1"}).json()
    a2 = client.post(f"/projects/{p1['id']}/tasks", json={"title": "A2"}).json()
    b1 = client.post(f"/projects/{p2['id']}/tasks", json={"title": "B1"}).json()

    assert (a1["number"], a1["key"]) == (1, "ALP-1")
    assert (a2["number"], a2["key"]) == (2, "ALP-2")
    assert (b1["number"], b1["key"]) == (1, "BET-1")  # restarts per project


def test_create_task_requires_title(client):
    project = _make_project(client)
    resp = client.post(f"/projects/{project['id']}/tasks", json={})
    assert resp.status_code == 422


def test_create_task_project_not_found(client):
    resp = client.post("/projects/9999/tasks", json={"title": "x"})
    assert resp.status_code == 404


def test_get_task(client):
    project = _make_project(client)
    task = client.post(f"/projects/{project['id']}/tasks", json={"title": "T1"}).json()
    resp = client.get(f"/tasks/{task['id']}")
    assert resp.status_code == 200
    assert resp.json()["title"] == "T1"


def test_get_task_not_found(client):
    assert client.get("/tasks/9999").status_code == 404


def test_update_task_fields(client):
    project = _make_project(client)
    task = client.post(f"/projects/{project['id']}/tasks", json={"title": "T1"}).json()
    resp = client.patch(
        f"/tasks/{task['id']}",
        json={"title": "Renamed", "priority": "high", "due_date": "2026-08-01"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["title"] == "Renamed"
    assert body["priority"] == "high"
    assert body["due_date"] == "2026-08-01"


def test_update_task_can_clear_due_date(client):
    project = _make_project(client)
    task = client.post(
        f"/projects/{project['id']}/tasks", json={"title": "T1", "due_date": "2026-08-01"}
    ).json()
    resp = client.patch(f"/tasks/{task['id']}", json={"due_date": None})
    assert resp.status_code == 200
    assert resp.json()["due_date"] is None


def test_update_task_not_found(client):
    resp = client.patch("/tasks/9999", json={"title": "x"})
    assert resp.status_code == 404


def test_update_task_rejects_blank_title(client):
    project = _make_project(client)
    task = client.post(f"/projects/{project['id']}/tasks", json={"title": "T1"}).json()
    resp = client.patch(f"/tasks/{task['id']}", json={"title": ""})
    assert resp.status_code == 422


def test_moving_status_appends_to_end_of_target_column(client):
    project = _make_project(client)
    # Two tasks already sitting in `in_progress`.
    existing_1 = client.post(
        f"/projects/{project['id']}/tasks", json={"title": "E1", "status": "in_progress"}
    ).json()
    existing_2 = client.post(
        f"/projects/{project['id']}/tasks", json={"title": "E2", "status": "in_progress"}
    ).json()
    mover = client.post(f"/projects/{project['id']}/tasks", json={"title": "Mover"}).json()

    resp = client.patch(f"/tasks/{mover['id']}", json={"status": "in_progress"})
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "in_progress"
    assert body["position"] > existing_1["position"]
    assert body["position"] > existing_2["position"]


def test_moving_status_with_explicit_position_does_not_append(client):
    project = _make_project(client)
    task = client.post(f"/projects/{project['id']}/tasks", json={"title": "T1"}).json()
    resp = client.patch(f"/tasks/{task['id']}", json={"status": "done", "position": 5.5})
    assert resp.status_code == 200
    assert resp.json()["position"] == 5.5


def test_delete_task(client):
    project = _make_project(client)
    task = client.post(f"/projects/{project['id']}/tasks", json={"title": "T1"}).json()
    assert client.delete(f"/tasks/{task['id']}").status_code == 204
    assert client.get(f"/tasks/{task['id']}").status_code == 404


def test_delete_task_not_found(client):
    assert client.delete("/tasks/9999").status_code == 404


def test_board_groups_by_status(client):
    project = _make_project(client)
    client.post(f"/projects/{project['id']}/tasks", json={"title": "T1"})
    t2 = client.post(
        f"/projects/{project['id']}/tasks", json={"title": "T2", "status": "in_progress"}
    ).json()
    t3 = client.post(
        f"/projects/{project['id']}/tasks", json={"title": "T3", "status": "done"}
    ).json()

    resp = client.get(f"/projects/{project['id']}/board")
    assert resp.status_code == 200
    board = resp.json()
    assert {t["title"] for t in board["todo"]} == {"T1"}
    assert [t["id"] for t in board["in_progress"]] == [t2["id"]]
    assert [t["id"] for t in board["done"]] == [t3["id"]]


def test_board_not_found_for_unknown_project(client):
    assert client.get("/projects/9999/board").status_code == 404


def test_list_tasks_not_found_for_unknown_project(client):
    assert client.get("/projects/9999/tasks").status_code == 404
