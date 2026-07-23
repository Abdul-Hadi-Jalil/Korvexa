"""Phase 4: consistent error envelope, request ids, rate limiting, and a few
validation edge cases.
"""


def test_error_envelope_has_detail_and_request_id(client):
    resp = client.get("/projects/999999")
    assert resp.status_code == 404
    body = resp.json()
    assert body["detail"] == "Project not found"
    assert "request_id" in body and body["request_id"] != "-"


def test_validation_error_envelope(raw_client):
    resp = raw_client.post("/auth/register", json={"email": "bad", "name": "", "password": "x"})
    assert resp.status_code == 422
    body = resp.json()
    assert body["detail"] == "Validation error"
    assert isinstance(body["errors"], list) and len(body["errors"]) >= 1
    assert "request_id" in body


def test_request_id_header_present(client):
    resp = client.get("/health")
    assert "X-Request-ID" in resp.headers


def test_request_id_echoes_inbound_header(client):
    resp = client.get("/health", headers={"X-Request-ID": "trace-abc-123"})
    assert resp.headers["X-Request-ID"] == "trace-abc-123"


def test_401_uses_error_envelope(raw_client):
    resp = raw_client.get("/projects")
    assert resp.status_code == 401
    body = resp.json()
    assert body["detail"] == "Not authenticated"
    assert "request_id" in body


def test_rate_limit_triggers_on_login(raw_client):
    # Re-enable the limiter (the fixtures disable it globally) for this test.
    from app.main import app

    app.state.limiter.enabled = True
    try:
        codes = [
            raw_client.post(
                "/auth/login", json={"email": "nobody@example.com", "password": "password123"}
            ).status_code
            for _ in range(15)
        ]
    finally:
        app.state.limiter.enabled = False
        app.state.limiter.reset()

    assert 429 in codes  # somewhere in the burst we got throttled


def test_task_list_limit_is_clamped(client):
    project = client.post("/projects", json={"name": "P"}).json()
    for i in range(3):
        client.post(f"/projects/{project['id']}/tasks", json={"title": f"T{i}"})
    # An absurd limit is clamped to the max (<=200) rather than erroring.
    page = client.get(f"/projects/{project['id']}/tasks", params={"limit": 100000}).json()
    assert page["limit"] <= 200
    assert page["total"] == 3


def test_negative_offset_is_clamped(client):
    project = client.post("/projects", json={"name": "P"}).json()
    client.post(f"/projects/{project['id']}/tasks", json={"title": "T"})
    page = client.get(f"/projects/{project['id']}/tasks", params={"offset": -5}).json()
    assert page["offset"] == 0


def test_invalid_status_enum_rejected(client):
    project = client.post("/projects", json={"name": "P"}).json()
    resp = client.post(f"/projects/{project['id']}/tasks", json={"title": "T", "status": "bogus"})
    assert resp.status_code == 422
