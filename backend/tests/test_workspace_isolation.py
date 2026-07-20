"""Proves the hard rule from the working agreement: a user can never read or
write another workspace's data.

Phase 1 has no auth yet, so there is no API to create a *second* workspace --
`get_current_workspace` always resolves the one seeded on first use. To
exercise cross-workspace access we insert a second workspace/project/task
directly at the DB layer (simulating "some other tenant's data") and confirm
every route scoped by workspace treats it as if it doesn't exist.
"""
from app.models import Project, Task, User, Workspace


def _seed_other_workspace(session):
    other_user = User(email="other@example.com", name="Other Owner")
    session.add(other_user)
    session.flush()

    other_workspace = Workspace(name="Someone Else's Workspace", owner_id=other_user.id)
    session.add(other_workspace)
    session.flush()

    other_project = Project(
        workspace_id=other_workspace.id, name="Secret Project", key="SEC", task_counter=1
    )
    session.add(other_project)
    session.flush()

    other_task = Task(project_id=other_project.id, number=1, title="Secret task", status="todo")
    session.add(other_task)
    session.commit()
    session.refresh(other_project)
    session.refresh(other_task)
    return other_project, other_task


def test_cannot_read_other_workspace_project(client, session):
    # Trigger seeding of *our* workspace first.
    client.get("/projects")
    other_project, _other_task = _seed_other_workspace(session)

    assert client.get(f"/projects/{other_project.id}").status_code == 404


def test_cannot_update_other_workspace_project(client, session):
    client.get("/projects")
    other_project, _ = _seed_other_workspace(session)

    resp = client.patch(f"/projects/{other_project.id}", json={"description": "hijacked"})
    assert resp.status_code == 404


def test_cannot_delete_other_workspace_project(client, session):
    client.get("/projects")
    other_project, _ = _seed_other_workspace(session)

    assert client.delete(f"/projects/{other_project.id}").status_code == 404


def test_other_workspace_project_not_in_list(client, session):
    client.get("/projects")
    other_project, _ = _seed_other_workspace(session)

    names = {p["name"] for p in client.get("/projects").json()}
    assert other_project.name not in names


def test_cannot_read_other_workspace_task(client, session):
    client.get("/projects")
    _other_project, other_task = _seed_other_workspace(session)

    assert client.get(f"/tasks/{other_task.id}").status_code == 404


def test_cannot_update_other_workspace_task(client, session):
    client.get("/projects")
    _other_project, other_task = _seed_other_workspace(session)

    resp = client.patch(f"/tasks/{other_task.id}", json={"title": "hijacked"})
    assert resp.status_code == 404


def test_cannot_delete_other_workspace_task(client, session):
    client.get("/projects")
    _other_project, other_task = _seed_other_workspace(session)

    assert client.delete(f"/tasks/{other_task.id}").status_code == 404


def test_cannot_list_tasks_of_other_workspace_project(client, session):
    client.get("/projects")
    other_project, _ = _seed_other_workspace(session)

    assert client.get(f"/projects/{other_project.id}/tasks").status_code == 404


def test_cannot_view_board_of_other_workspace_project(client, session):
    client.get("/projects")
    other_project, _ = _seed_other_workspace(session)

    assert client.get(f"/projects/{other_project.id}/board").status_code == 404


def test_cannot_create_task_in_other_workspace_project(client, session):
    client.get("/projects")
    other_project, _ = _seed_other_workspace(session)

    resp = client.post(f"/projects/{other_project.id}/tasks", json={"title": "hijack"})
    assert resp.status_code == 404


def test_upcoming_excludes_other_workspace_tasks(client, session):
    client.get("/projects")
    _other_project, other_task = _seed_other_workspace(session)

    titles = {t["title"] for t in client.get("/me/upcoming", params={"window": "all"}).json()}
    assert other_task.title not in titles
