def _make_task(client):
    project = client.post("/projects", json={"name": "Alpha"}).json()
    return client.post(f"/projects/{project['id']}/tasks", json={"title": "T1"}).json()


def test_create_and_list_comment(client):
    task = _make_task(client)
    resp = client.post(f"/tasks/{task['id']}/comments", json={"body": "First comment"})
    assert resp.status_code == 201
    body = resp.json()
    assert body["body"] == "First comment"
    assert body["author_id"] is not None
    assert body["author_name"] is not None

    listed = client.get(f"/tasks/{task['id']}/comments")
    assert listed.status_code == 200
    page = listed.json()
    assert page["total"] == 1
    assert page["items"][0]["body"] == "First comment"


def test_comment_requires_body(client):
    task = _make_task(client)
    resp = client.post(f"/tasks/{task['id']}/comments", json={"body": ""})
    assert resp.status_code == 422


def test_comment_on_missing_task_404(client):
    resp = client.post("/tasks/9999/comments", json={"body": "hi"})
    assert resp.status_code == 404


def test_update_comment(client):
    task = _make_task(client)
    comment = client.post(f"/tasks/{task['id']}/comments", json={"body": "orig"}).json()
    resp = client.patch(f"/comments/{comment['id']}", json={"body": "edited"})
    assert resp.status_code == 200
    assert resp.json()["body"] == "edited"


def test_update_comment_not_found(client):
    resp = client.patch("/comments/9999", json={"body": "x"})
    assert resp.status_code == 404


def test_delete_comment(client):
    task = _make_task(client)
    comment = client.post(f"/tasks/{task['id']}/comments", json={"body": "orig"}).json()
    assert client.delete(f"/comments/{comment['id']}").status_code == 204

    listed = client.get(f"/tasks/{task['id']}/comments")
    assert listed.json()["total"] == 0


def test_delete_comment_not_found(client):
    assert client.delete("/comments/9999").status_code == 404


def test_comments_paginated(client):
    task = _make_task(client)
    for i in range(5):
        client.post(f"/tasks/{task['id']}/comments", json={"body": f"c{i}"})

    page = client.get(f"/tasks/{task['id']}/comments", params={"limit": 2, "offset": 0}).json()
    assert page["total"] == 5
    assert len(page["items"]) == 2
    assert page["limit"] == 2

    page2 = client.get(f"/tasks/{task['id']}/comments", params={"limit": 2, "offset": 4}).json()
    assert len(page2["items"]) == 1


def test_comments_ordered_by_creation(client):
    task = _make_task(client)
    client.post(f"/tasks/{task['id']}/comments", json={"body": "first"})
    client.post(f"/tasks/{task['id']}/comments", json={"body": "second"})
    items = client.get(f"/tasks/{task['id']}/comments").json()["items"]
    assert [c["body"] for c in items] == ["first", "second"]
