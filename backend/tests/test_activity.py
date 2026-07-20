def _make_task(client):
    project = client.post("/projects", json={"name": "Alpha"}).json()
    task = client.post(f"/projects/{project['id']}/tasks", json={"title": "T1"}).json()
    return project, task


def test_creation_logs_activity(client):
    _project, task = _make_task(client)
    activity = client.get(f"/tasks/{task['id']}/activity").json()
    assert len(activity) == 1
    assert activity[0]["action"] == "created"


def test_status_change_logs_activity(client):
    _project, task = _make_task(client)
    client.patch(f"/tasks/{task['id']}", json={"status": "in_progress"})

    activity = client.get(f"/tasks/{task['id']}/activity").json()
    actions = [a["action"] for a in activity]
    assert "status_changed" in actions
    status_entry = next(a for a in activity if a["action"] == "status_changed")
    assert status_entry["field"] == "status"
    assert status_entry["old_value"] == "todo"
    assert status_entry["new_value"] == "in_progress"


def test_field_edit_logs_activity(client):
    _project, task = _make_task(client)
    client.patch(f"/tasks/{task['id']}", json={"title": "Renamed", "priority": "high"})

    activity = client.get(f"/tasks/{task['id']}/activity").json()
    fields = {a["field"] for a in activity if a["action"] == "updated"}
    assert "title" in fields
    assert "priority" in fields


def test_noop_update_does_not_log(client):
    _project, task = _make_task(client)
    # PATCH with the same title -> no change -> no new activity entry.
    client.patch(f"/tasks/{task['id']}", json={"title": "T1"})

    activity = client.get(f"/tasks/{task['id']}/activity").json()
    # Only the original "created" entry.
    assert [a["action"] for a in activity] == ["created"]


def test_activity_newest_first(client):
    _project, task = _make_task(client)
    client.patch(f"/tasks/{task['id']}", json={"status": "in_progress"})
    client.patch(f"/tasks/{task['id']}", json={"status": "done"})

    activity = client.get(f"/tasks/{task['id']}/activity").json()
    # Most recent status change (todo->...->done) should be at the top.
    assert activity[0]["action"] == "status_changed"
    assert activity[0]["new_value"] == "done"
    assert activity[-1]["action"] == "created"


def test_activity_not_found_for_unknown_task(client):
    assert client.get("/tasks/9999/activity").status_code == 404


def test_reorder_does_not_log_activity(client):
    _project, task = _make_task(client)
    client.post(f"/tasks/{task['id']}/reorder", json={"position": 3.0})

    activity = client.get(f"/tasks/{task['id']}/activity").json()
    assert [a["action"] for a in activity] == ["created"]
