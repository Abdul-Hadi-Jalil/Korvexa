"""Phase 3: assignees + in-app notifications (assignment and @mention)."""


def _setup_shared_workspace(client, register_client):
    """Owner (client) invites Bob into their workspace; returns Bob's context
    plus Bob's user id and a project id in the shared workspace.
    """
    bob = register_client("bob@example.com", "Bob")
    workspace_id = client.auth_context["workspace_id"]
    client.post(f"/workspaces/{workspace_id}/invite", json={"email": "bob@example.com", "role": "member"})
    members = client.get(f"/workspaces/{workspace_id}/members").json()
    bob_id = next(m["user_id"] for m in members if m["email"] == "bob@example.com")
    project = client.post("/projects", json={"name": "Shared"}).json()
    bob["headers"] = {"Authorization": f"Bearer {bob['access_token']}", "X-Workspace-Id": str(workspace_id)}
    bob["user_id"] = bob_id
    return bob, project


def test_assign_task_to_member(client, register_client):
    bob, project = _setup_shared_workspace(client, register_client)
    task = client.post(f"/projects/{project['id']}/tasks", json={"title": "T"}).json()
    resp = client.patch(f"/tasks/{task['id']}", json={"assignee_id": bob["user_id"]})
    assert resp.status_code == 200
    assert resp.json()["assignee_id"] == bob["user_id"]


def test_cannot_assign_non_member(client, register_client):
    # Carol is registered but NOT a member of the owner's workspace, so she
    # can't be assigned (nor can any non-member id).
    register_client("carol@example.com", "Carol")
    project = client.post("/projects", json={"name": "P"}).json()
    task = client.post(f"/projects/{project['id']}/tasks", json={"title": "T"}).json()
    resp = client.patch(f"/tasks/{task['id']}", json={"assignee_id": 999999})
    assert resp.status_code == 400


def test_assignment_creates_notification_for_assignee(client, register_client):
    bob, project = _setup_shared_workspace(client, register_client)
    task = client.post(f"/projects/{project['id']}/tasks", json={"title": "Do it"}).json()
    client.patch(f"/tasks/{task['id']}", json={"assignee_id": bob["user_id"]})

    notifications = client.get("/notifications", headers=bob["headers"]).json()
    assert len(notifications) == 1
    assert notifications[0]["type"] == "assigned"
    assert notifications[0]["task_id"] == task["id"]


def test_self_assignment_does_not_notify(client):
    owner_id = _owner_id(client)
    project = client.post("/projects", json={"name": "P"}).json()
    task = client.post(f"/projects/{project['id']}/tasks", json={"title": "T"}).json()
    client.patch(f"/tasks/{task['id']}", json={"assignee_id": owner_id})

    notifications = client.get("/notifications").json()
    assert notifications == []


def test_mention_creates_notification(client, register_client):
    bob, project = _setup_shared_workspace(client, register_client)
    task = client.post(f"/projects/{project['id']}/tasks", json={"title": "T"}).json()
    # Owner mentions bob by the local-part of his email.
    client.post(f"/tasks/{task['id']}/comments", json={"body": "hey @bob please look"})

    notifications = client.get("/notifications", headers=bob["headers"]).json()
    assert len(notifications) == 1
    assert notifications[0]["type"] == "mention"


def test_mention_of_non_member_creates_nothing(client, register_client):
    _bob, project = _setup_shared_workspace(client, register_client)
    task = client.post(f"/projects/{project['id']}/tasks", json={"title": "T"}).json()
    client.post(f"/tasks/{task['id']}/comments", json={"body": "hi @nobody"})
    # Owner has no notification (they authored it); nobody else matches.
    assert client.get("/notifications").json() == []


def test_mark_notification_read(client, register_client):
    bob, project = _setup_shared_workspace(client, register_client)
    task = client.post(f"/projects/{project['id']}/tasks", json={"title": "T"}).json()
    client.patch(f"/tasks/{task['id']}", json={"assignee_id": bob["user_id"]})

    notif = client.get("/notifications", headers=bob["headers"]).json()[0]
    assert client.get("/notifications/unread_count", headers=bob["headers"]).json()["unread"] == 1

    resp = client.post(f"/notifications/{notif['id']}/read", headers=bob["headers"])
    assert resp.status_code == 200
    assert resp.json()["read"] is True
    assert client.get("/notifications/unread_count", headers=bob["headers"]).json()["unread"] == 0


def test_cannot_read_others_notification(client, register_client):
    bob, project = _setup_shared_workspace(client, register_client)
    task = client.post(f"/projects/{project['id']}/tasks", json={"title": "T"}).json()
    client.patch(f"/tasks/{task['id']}", json={"assignee_id": bob["user_id"]})
    notif = client.get("/notifications", headers=bob["headers"]).json()[0]

    # Owner tries to mark Bob's notification read -> 404 (not theirs).
    assert client.post(f"/notifications/{notif['id']}/read").status_code == 404


def test_mark_all_notifications_read(client, register_client):
    bob, project = _setup_shared_workspace(client, register_client)
    for i in range(3):
        task = client.post(f"/projects/{project['id']}/tasks", json={"title": f"T{i}"}).json()
        client.patch(f"/tasks/{task['id']}", json={"assignee_id": bob["user_id"]})

    assert client.get("/notifications/unread_count", headers=bob["headers"]).json()["unread"] == 3
    resp = client.post("/notifications/read_all", headers=bob["headers"])
    assert resp.status_code == 200
    assert resp.json()["marked"] == 3
    assert client.get("/notifications/unread_count", headers=bob["headers"]).json()["unread"] == 0


def test_list_unread_only(client, register_client):
    bob, project = _setup_shared_workspace(client, register_client)
    t1 = client.post(f"/projects/{project['id']}/tasks", json={"title": "A"}).json()
    t2 = client.post(f"/projects/{project['id']}/tasks", json={"title": "B"}).json()
    client.patch(f"/tasks/{t1['id']}", json={"assignee_id": bob["user_id"]})
    client.patch(f"/tasks/{t2['id']}", json={"assignee_id": bob["user_id"]})

    notifs = client.get("/notifications", headers=bob["headers"]).json()
    client.post(f"/notifications/{notifs[0]['id']}/read", headers=bob["headers"])

    unread = client.get("/notifications", params={"unread_only": True}, headers=bob["headers"]).json()
    assert len(unread) == 1


def test_my_tasks_filters_by_assignee(client, register_client):
    bob, project = _setup_shared_workspace(client, register_client)
    assigned = client.post(f"/projects/{project['id']}/tasks", json={"title": "For Bob"}).json()
    client.patch(f"/tasks/{assigned['id']}", json={"assignee_id": bob["user_id"]})
    client.post(f"/projects/{project['id']}/tasks", json={"title": "Unassigned"})

    mine = client.get("/me/upcoming", params={"window": "all", "mine": True}, headers=bob["headers"]).json()
    titles = {t["title"] for t in mine}
    assert titles == {"For Bob"}


def _owner_id(client):
    workspace_id = client.auth_context["workspace_id"]
    members = client.get(f"/workspaces/{workspace_id}/members").json()
    return next(m["user_id"] for m in members if m["email"] == "owner@example.com")
