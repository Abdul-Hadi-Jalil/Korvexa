"""Multi-tenant isolation for Phase 2 resources: comments, labels, and
activity of another workspace's task must be unreachable.
"""
from app.models import Project, Task, User, Workspace


def _seed_other_workspace_task(session):
    other_user = User(email="other@example.com", name="Other Owner")
    session.add(other_user)
    session.flush()
    other_workspace = Workspace(name="Other WS", owner_id=other_user.id)
    session.add(other_workspace)
    session.flush()
    other_project = Project(workspace_id=other_workspace.id, name="Secret", key="SEC", task_counter=1)
    session.add(other_project)
    session.flush()
    other_task = Task(project_id=other_project.id, number=1, title="Secret task", status="todo")
    session.add(other_task)
    session.commit()
    session.refresh(other_task)
    return other_workspace, other_task


def test_cannot_list_comments_of_other_workspace_task(client, session):
    client.get("/projects")  # seed our workspace
    _ws, other_task = _seed_other_workspace_task(session)
    assert client.get(f"/tasks/{other_task.id}/comments").status_code == 404


def test_cannot_comment_on_other_workspace_task(client, session):
    client.get("/projects")
    _ws, other_task = _seed_other_workspace_task(session)
    assert client.post(f"/tasks/{other_task.id}/comments", json={"body": "x"}).status_code == 404


def test_cannot_read_activity_of_other_workspace_task(client, session):
    client.get("/projects")
    _ws, other_task = _seed_other_workspace_task(session)
    assert client.get(f"/tasks/{other_task.id}/activity").status_code == 404


def test_cannot_assign_label_to_other_workspace_task(client, session):
    client.get("/projects")
    _ws, other_task = _seed_other_workspace_task(session)
    label = client.post("/labels", json={"name": "bug"}).json()
    assert client.put(f"/tasks/{other_task.id}/labels", json=[label["id"]]).status_code == 404


def test_cannot_use_other_workspace_label(client, session):
    """A label from another workspace can't be attached to our own task."""
    client.get("/projects")
    other_ws, _other_task = _seed_other_workspace_task(session)

    # Create a label directly in the other workspace.
    from app.models import Label

    foreign_label = Label(workspace_id=other_ws.id, name="foreign")
    session.add(foreign_label)
    session.commit()
    session.refresh(foreign_label)

    # Our own task can't reference it.
    project = client.post("/projects", json={"name": "Mine"}).json()
    task = client.post(f"/projects/{project['id']}/tasks", json={"title": "T"}).json()
    resp = client.put(f"/tasks/{task['id']}/labels", json=[foreign_label.id])
    assert resp.status_code == 400
