from sqlmodel import func, select

from app.models import Comment, Project, Task, User, Workspace
from app.seed import OWNER_EMAIL, seed_demo


def test_seed_demo_populates_data(session):
    workspace = seed_demo(session)
    assert workspace.name == "Acme Product"

    users = session.exec(select(func.count()).select_from(User)).one()
    projects = session.exec(select(func.count()).select_from(Project)).one()
    tasks = session.exec(select(func.count()).select_from(Task)).one()
    comments = session.exec(select(func.count()).select_from(Comment)).one()

    assert users == 2  # owner + teammate
    assert projects == 2
    assert tasks == 6
    assert comments == 1


def test_seed_demo_is_idempotent(session):
    seed_demo(session)
    seed_demo(session)  # second run should be a no-op

    owners = session.exec(select(func.count()).select_from(User).where(User.email == OWNER_EMAIL)).one()
    workspaces = session.exec(select(func.count()).select_from(Workspace)).one()
    assert owners == 1
    assert workspaces == 1
