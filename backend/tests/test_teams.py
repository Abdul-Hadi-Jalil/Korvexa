"""Phase 3: real two-user multi-tenant isolation, invites, and roles."""


def test_user_b_cannot_see_user_a_workspace(client, register_client):
    # client == user A (owner@example.com), authenticated for workspace A.
    project = client.post("/projects", json={"name": "Secret A"}).json()

    b = register_client("b@example.com", "Bob")
    # Bob lists projects in HIS workspace -> empty, and can't fetch A's project.
    b_projects = client.get("/projects", headers=b["headers"]).json()
    assert b_projects == []
    resp = client.get(f"/projects/{project['id']}", headers=b["headers"])
    assert resp.status_code == 404


def test_user_cannot_spoof_workspace_via_header(client, register_client):
    b = register_client("b@example.com", "Bob")
    b_workspace_id = b["workspace_id"]

    # User A (client) tries to act on Bob's workspace by setting the header.
    resp = client.get(
        "/projects",
        headers={"Authorization": client.headers["Authorization"], "X-Workspace-Id": str(b_workspace_id)},
    )
    # A is not a member of Bob's workspace -> 404, can't even confirm it exists.
    assert resp.status_code == 404


def test_invite_adds_member(client, register_client):
    register_client("bob@example.com", "Bob")  # Bob already has an account
    workspace_id = client.auth_context["workspace_id"]

    resp = client.post(
        f"/workspaces/{workspace_id}/invite", json={"email": "bob@example.com", "role": "member"}
    )
    assert resp.status_code == 201
    assert resp.json()["email"] == "bob@example.com"
    assert resp.json()["role"] == "member"

    members = client.get(f"/workspaces/{workspace_id}/members").json()
    emails = {m["email"] for m in members}
    assert emails == {"owner@example.com", "bob@example.com"}


def test_invited_member_can_access_shared_workspace(client, register_client):
    bob = register_client("bob@example.com", "Bob")
    workspace_id = client.auth_context["workspace_id"]
    project = client.post("/projects", json={"name": "Shared"}).json()

    client.post(f"/workspaces/{workspace_id}/invite", json={"email": "bob@example.com", "role": "member"})

    # Bob, using the SHARED workspace id, can now see the project.
    bob_headers = {"Authorization": f"Bearer {bob['access_token']}", "X-Workspace-Id": str(workspace_id)}
    resp = client.get(f"/projects/{project['id']}", headers=bob_headers)
    assert resp.status_code == 200
    assert resp.json()["name"] == "Shared"


def test_invite_of_new_email_creates_claimable_account(client, raw_client):
    workspace_id = client.auth_context["workspace_id"]
    client.post(f"/workspaces/{workspace_id}/invite", json={"email": "new@example.com", "role": "member"})

    # The invited person registers with that email -> claims the placeholder
    # account and keeps the invited membership. (They already belong to a
    # workspace, so no redundant personal one is minted.)
    reg = raw_client.post(
        "/auth/register", json={"email": "new@example.com", "name": "New", "password": "password123"}
    )
    assert reg.status_code == 201
    token = reg.json()["access_token"]
    workspaces = raw_client.get("/workspaces", headers={"Authorization": f"Bearer {token}"}).json()
    ids = {w["id"] for w in workspaces}
    assert workspace_id in ids  # invited workspace present and accessible
    # And they can now authenticate and act (login works with the new password).
    login = raw_client.post("/auth/login", json={"email": "new@example.com", "password": "password123"})
    assert login.status_code == 200


def test_member_cannot_delete_project(client, register_client):
    bob = register_client("bob@example.com", "Bob")
    workspace_id = client.auth_context["workspace_id"]
    project = client.post("/projects", json={"name": "Shared"}).json()
    client.post(f"/workspaces/{workspace_id}/invite", json={"email": "bob@example.com", "role": "member"})

    bob_headers = {"Authorization": f"Bearer {bob['access_token']}", "X-Workspace-Id": str(workspace_id)}
    resp = client.delete(f"/projects/{project['id']}", headers=bob_headers)
    assert resp.status_code == 403  # owner-only


def test_owner_can_delete_project(client):
    project = client.post("/projects", json={"name": "Mine"}).json()
    assert client.delete(f"/projects/{project['id']}").status_code == 204


def test_member_cannot_invite(client, register_client):
    bob = register_client("bob@example.com", "Bob")
    workspace_id = client.auth_context["workspace_id"]
    client.post(f"/workspaces/{workspace_id}/invite", json={"email": "bob@example.com", "role": "member"})

    bob_headers = {"Authorization": f"Bearer {bob['access_token']}", "X-Workspace-Id": str(workspace_id)}
    resp = client.post(
        f"/workspaces/{workspace_id}/invite",
        json={"email": "carol@example.com", "role": "member"},
        headers=bob_headers,
    )
    assert resp.status_code == 403


def test_owner_can_remove_member(client, register_client):
    register_client("bob@example.com", "Bob")
    workspace_id = client.auth_context["workspace_id"]
    client.post(f"/workspaces/{workspace_id}/invite", json={"email": "bob@example.com", "role": "member"})
    bob_id = _user_id(client, workspace_id, "bob@example.com")

    resp = client.delete(f"/workspaces/{workspace_id}/members/{bob_id}")
    assert resp.status_code == 204
    emails = {m["email"] for m in client.get(f"/workspaces/{workspace_id}/members").json()}
    assert "bob@example.com" not in emails


def test_owner_cannot_remove_self(client):
    workspace_id = client.auth_context["workspace_id"]
    owner_id = _user_id(client, workspace_id, "owner@example.com")
    resp = client.delete(f"/workspaces/{workspace_id}/members/{owner_id}")
    assert resp.status_code == 400


def test_promote_member_to_owner(client, register_client):
    bob = register_client("bob@example.com", "Bob")
    workspace_id = client.auth_context["workspace_id"]
    client.post(f"/workspaces/{workspace_id}/invite", json={"email": "bob@example.com", "role": "member"})
    bob_id = _user_id(client, workspace_id, "bob@example.com")

    resp = client.patch(f"/workspaces/{workspace_id}/members/{bob_id}", json={"role": "owner"})
    assert resp.status_code == 200
    assert resp.json()["role"] == "owner"

    # Now Bob (as owner) can delete a project.
    project = client.post("/projects", json={"name": "P"}).json()
    bob_headers = {"Authorization": f"Bearer {bob['access_token']}", "X-Workspace-Id": str(workspace_id)}
    assert client.delete(f"/projects/{project['id']}", headers=bob_headers).status_code == 204


def test_create_second_workspace(client):
    resp = client.post("/workspaces", json={"name": "Second"})
    assert resp.status_code == 201
    assert resp.json()["role"] == "owner"
    workspaces = client.get("/workspaces").json()
    assert len(workspaces) == 2


def _user_id(client, workspace_id, email):
    members = client.get(f"/workspaces/{workspace_id}/members").json()
    return next(m["user_id"] for m in members if m["email"] == email)
