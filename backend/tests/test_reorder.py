"""Reorder stability: moving one card writes only that card's row, and the
relative order of the others is unchanged.
"""


def _make_column(client, n=3):
    project = client.post("/projects", json={"name": "Alpha"}).json()
    tasks = [
        client.post(f"/projects/{project['id']}/tasks", json={"title": f"T{i}"}).json()
        for i in range(n)
    ]
    return project, tasks


def _todo_ids(client, project_id):
    board = client.get(f"/projects/{project_id}/board").json()
    return [t["id"] for t in board["todo"]]


def test_reorder_with_explicit_position(client):
    project, tasks = _make_column(client, 3)
    resp = client.post(f"/tasks/{tasks[2]['id']}/reorder", json={"position": 0.5})
    assert resp.status_code == 200
    assert resp.json()["position"] == 0.5
    # Now first in the column.
    assert _todo_ids(client, project["id"])[0] == tasks[2]["id"]


def test_reorder_between_two_tasks(client):
    project, tasks = _make_column(client, 3)
    # Move last task to sit between task0 and task1.
    resp = client.post(
        f"/tasks/{tasks[2]['id']}/reorder",
        json={"after_id": tasks[0]["id"], "before_id": tasks[1]["id"]},
    )
    assert resp.status_code == 200
    order = _todo_ids(client, project["id"])
    assert order == [tasks[0]["id"], tasks[2]["id"], tasks[1]["id"]]


def test_reorder_to_start(client):
    project, tasks = _make_column(client, 3)
    resp = client.post(f"/tasks/{tasks[2]['id']}/reorder", json={"before_id": tasks[0]["id"]})
    assert resp.status_code == 200
    assert _todo_ids(client, project["id"])[0] == tasks[2]["id"]


def test_reorder_only_touches_moved_row(client):
    project, tasks = _make_column(client, 3)
    positions_before = {t["id"]: client.get(f"/tasks/{t['id']}").json()["position"] for t in tasks}

    client.post(
        f"/tasks/{tasks[2]['id']}/reorder",
        json={"after_id": tasks[0]["id"], "before_id": tasks[1]["id"]},
    )

    # The two tasks that didn't move keep their exact positions.
    for other in (tasks[0], tasks[1]):
        after = client.get(f"/tasks/{other['id']}").json()["position"]
        assert after == positions_before[other["id"]]


def test_reorder_not_found(client):
    resp = client.post("/tasks/9999/reorder", json={"position": 1.0})
    assert resp.status_code == 404


def test_reorder_sibling_in_other_project_rejected(client):
    _p1, tasks1 = _make_column(client, 1)
    _p2, tasks2 = _make_column(client, 1)
    resp = client.post(
        f"/tasks/{tasks1[0]['id']}/reorder", json={"before_id": tasks2[0]["id"]}
    )
    assert resp.status_code == 400
