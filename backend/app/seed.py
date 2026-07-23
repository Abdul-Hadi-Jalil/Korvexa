"""Demo-data seeding.

`seed_demo()` populates a realistic starting point: an owner + a second
member, one workspace, two projects, labels, tasks across the board, an
assignment, and a comment. It's idempotent on the owner's email, so running
it twice won't duplicate. Invoke via the module CLI:

    python -m app.seed            # seed into $DATABASE_URL
    python -m app.seed --reset    # drop+recreate schema first, then seed

Requires the schema to exist (run `alembic upgrade head` first, or use
`--reset` which stamps via metadata for a throwaway demo DB).
"""
from __future__ import annotations

import argparse
from datetime import date, timedelta

from sqlmodel import Session, select

from app.core.security import hash_password
from app.db import engine
from app.models import (
    Comment,
    Label,
    Membership,
    MembershipRole,
    Project,
    Task,
    TaskLabel,
    TaskPriority,
    TaskStatus,
    User,
    Workspace,
)
from app.utils.position import POSITION_GAP

OWNER_EMAIL = "demo@korvexa.app"
OWNER_PASSWORD = "demo-password-123"
MEMBER_EMAIL = "teammate@korvexa.app"


def seed_demo(session: Session) -> Workspace:
    existing = session.exec(select(User).where(User.email == OWNER_EMAIL)).first()
    if existing is not None:
        workspace = session.exec(
            select(Workspace).where(Workspace.owner_id == existing.id)
        ).first()
        if workspace is not None:
            print(f"Demo data already present (owner={OWNER_EMAIL}); nothing to do.")
            return workspace

    owner = User(email=OWNER_EMAIL, name="Demo Owner", password_hash=hash_password(OWNER_PASSWORD))
    member = User(email=MEMBER_EMAIL, name="Demo Teammate", password_hash=hash_password(OWNER_PASSWORD))
    session.add(owner)
    session.add(member)
    session.flush()

    workspace = Workspace(name="Acme Product", owner_id=owner.id)
    session.add(workspace)
    session.flush()
    session.add(Membership(workspace_id=workspace.id, user_id=owner.id, role=MembershipRole.owner.value))
    session.add(Membership(workspace_id=workspace.id, user_id=member.id, role=MembershipRole.member.value))

    bug = Label(workspace_id=workspace.id, name="bug", color="#e53935")
    feature = Label(workspace_id=workspace.id, name="feature", color="#43a047")
    session.add(bug)
    session.add(feature)
    session.flush()

    web = Project(workspace_id=workspace.id, name="Web App", key="WEB")
    api = Project(workspace_id=workspace.id, name="Public API", key="API")
    session.add(web)
    session.add(api)
    session.flush()

    today = date.today()
    specs = [
        (web, "Set up CI pipeline", TaskStatus.done, TaskPriority.medium, None, None, []),
        (web, "Design landing page", TaskStatus.in_progress, TaskPriority.high, member.id,
         today + timedelta(days=2), [feature.id]),
        (web, "Fix mobile nav overflow", TaskStatus.todo, TaskPriority.high, None,
         today - timedelta(days=1), [bug.id]),
        (web, "Add dark mode", TaskStatus.todo, TaskPriority.low, None, None, [feature.id]),
        (api, "Rate limit auth endpoints", TaskStatus.done, TaskPriority.high, None, None, []),
        (api, "Write OpenAPI examples", TaskStatus.todo, TaskPriority.medium, owner.id,
         today + timedelta(days=5), []),
    ]

    first_task: Task | None = None
    for project, title, status, priority, assignee_id, due, label_ids in specs:
        project.task_counter += 1
        task = Task(
            project_id=project.id,
            number=project.task_counter,
            title=title,
            status=status.value,
            priority=priority.value,
            assignee_id=assignee_id,
            due_date=due,
            position=project.task_counter * POSITION_GAP,
        )
        session.add(project)
        session.add(task)
        session.flush()
        for label_id in label_ids:
            session.add(TaskLabel(task_id=task.id, label_id=label_id))
        first_task = first_task or task

    if first_task is not None:
        session.add(
            Comment(task_id=first_task.id, author_id=owner.id, body="Kicking this off — @teammate can you take a look?")
        )

    session.commit()
    print(
        "Seeded demo data:\n"
        f"  owner  : {OWNER_EMAIL} / {OWNER_PASSWORD}\n"
        f"  member : {MEMBER_EMAIL} / {OWNER_PASSWORD}\n"
        f"  workspace: {workspace.name} (id={workspace.id})"
    )
    return workspace


def main() -> None:
    parser = argparse.ArgumentParser(description="Seed Korvexa demo data.")
    parser.add_argument(
        "--reset",
        action="store_true",
        help="Drop and recreate all tables first (throwaway demo DBs only).",
    )
    args = parser.parse_args()

    if args.reset:
        from sqlmodel import SQLModel

        import app.models  # noqa: F401  (register tables)

        SQLModel.metadata.drop_all(engine)
        SQLModel.metadata.create_all(engine)
        print("Schema reset (drop_all + create_all).")

    with Session(engine) as session:
        seed_demo(session)


if __name__ == "__main__":
    main()
