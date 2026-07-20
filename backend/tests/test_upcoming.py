from datetime import date, timedelta


def _make_project(client, name="Alpha"):
    return client.post("/projects", json={"name": name}).json()


def _make_task(client, project_id, **kwargs):
    payload = {"title": "T"}
    payload.update(kwargs)
    return client.post(f"/projects/{project_id}/tasks", json=payload).json()


def test_upcoming_today_includes_overdue_and_today_excludes_future(client):
    project = _make_project(client)
    today = date.today()

    overdue = _make_task(client, project["id"], title="Overdue", due_date=str(today - timedelta(days=2)))
    due_today = _make_task(client, project["id"], title="DueToday", due_date=str(today))
    due_next_week = _make_task(client, project["id"], title="NextWeek", due_date=str(today + timedelta(days=10)))
    no_due_date = _make_task(client, project["id"], title="NoDueDate")

    resp = client.get("/me/upcoming", params={"window": "today"})
    assert resp.status_code == 200
    titles = {t["title"] for t in resp.json()}
    assert titles == {"Overdue", "DueToday"}
    assert "NextWeek" not in titles
    assert "NoDueDate" not in titles


def test_upcoming_week_window(client):
    project = _make_project(client)
    today = date.today()

    _make_task(client, project["id"], title="Overdue", due_date=str(today - timedelta(days=1)))
    _make_task(client, project["id"], title="InFiveDays", due_date=str(today + timedelta(days=5)))
    _make_task(client, project["id"], title="InThreeWeeks", due_date=str(today + timedelta(days=21)))

    resp = client.get("/me/upcoming", params={"window": "week"})
    titles = {t["title"] for t in resp.json()}
    assert titles == {"Overdue", "InFiveDays"}


def test_upcoming_all_includes_tasks_without_due_date(client):
    project = _make_project(client)
    today = date.today()

    _make_task(client, project["id"], title="Far", due_date=str(today + timedelta(days=90)))
    _make_task(client, project["id"], title="NoDueDate")

    resp = client.get("/me/upcoming", params={"window": "all"})
    titles = {t["title"] for t in resp.json()}
    assert titles == {"Far", "NoDueDate"}


def test_upcoming_excludes_done(client):
    project = _make_project(client)
    today = date.today()
    task = _make_task(client, project["id"], title="Done soon", due_date=str(today))
    client.patch(f"/tasks/{task['id']}", json={"status": "done"})

    resp = client.get("/me/upcoming", params={"window": "all"})
    titles = {t["title"] for t in resp.json()}
    assert "Done soon" not in titles


def test_upcoming_sorted_by_due_date_then_priority(client):
    project = _make_project(client)
    today = date.today()

    low_today = _make_task(client, project["id"], title="LowToday", due_date=str(today), priority="low")
    high_today = _make_task(client, project["id"], title="HighToday", due_date=str(today), priority="high")
    tomorrow = _make_task(client, project["id"], title="Tomorrow", due_date=str(today + timedelta(days=1)))

    resp = client.get("/me/upcoming", params={"window": "all"})
    titles = [t["title"] for t in resp.json()]
    assert titles == ["HighToday", "LowToday", "Tomorrow"]


def test_upcoming_shows_project_info(client):
    project = _make_project(client, name="Marketing")
    _make_task(client, project["id"], title="T1", due_date=str(date.today()))

    resp = client.get("/me/upcoming", params={"window": "all"})
    body = resp.json()[0]
    assert body["project_name"] == "Marketing"
    assert body["project_key"] == project["key"]
    assert body["key"] == f"{project['key']}-1"


def test_upcoming_invalid_window_rejected(client):
    resp = client.get("/me/upcoming", params={"window": "nonsense"})
    assert resp.status_code == 422
