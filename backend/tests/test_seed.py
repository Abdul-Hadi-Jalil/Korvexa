from sqlmodel import select

from app.models import Membership, User, Workspace


def test_first_request_seeds_one_user_workspace_membership(client, session):
    client.get("/health")  # doesn't touch get_current_workspace
    client.get("/projects")  # does -> triggers seeding

    users = session.exec(select(User)).all()
    workspaces = session.exec(select(Workspace)).all()
    memberships = session.exec(select(Membership)).all()

    assert len(users) == 1
    assert len(workspaces) == 1
    assert len(memberships) == 1
    assert memberships[0].role == "owner"
    assert memberships[0].workspace_id == workspaces[0].id
    assert memberships[0].user_id == users[0].id
    assert workspaces[0].owner_id == users[0].id


def test_seeding_is_idempotent(client, session):
    client.get("/projects")
    client.get("/projects")
    client.get("/projects")

    assert len(session.exec(select(Workspace)).all()) == 1
    assert len(session.exec(select(User)).all()) == 1
