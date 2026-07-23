def _register(raw_client, email="a@example.com", name="Alice", password="password123"):
    return raw_client.post(
        "/auth/register", json={"email": email, "name": name, "password": password}
    )


def test_register_returns_tokens(raw_client):
    resp = _register(raw_client)
    assert resp.status_code == 201
    body = resp.json()
    assert body["access_token"]
    assert body["refresh_token"]
    assert body["token_type"] == "bearer"


def test_register_creates_default_workspace(raw_client):
    _register(raw_client)
    login = raw_client.post("/auth/login", json={"email": "a@example.com", "password": "password123"})
    token = login.json()["access_token"]
    workspaces = raw_client.get("/workspaces", headers={"Authorization": f"Bearer {token}"}).json()
    assert len(workspaces) == 1
    assert workspaces[0]["role"] == "owner"


def test_register_duplicate_email_conflicts(raw_client):
    _register(raw_client)
    resp = _register(raw_client)
    assert resp.status_code == 409


def test_register_rejects_short_password(raw_client):
    resp = _register(raw_client, password="short")
    assert resp.status_code == 422


def test_register_rejects_invalid_email(raw_client):
    resp = _register(raw_client, email="not-an-email")
    assert resp.status_code == 422


def test_login_success(raw_client):
    _register(raw_client)
    resp = raw_client.post("/auth/login", json={"email": "a@example.com", "password": "password123"})
    assert resp.status_code == 200
    assert resp.json()["access_token"]


def test_login_wrong_password(raw_client):
    _register(raw_client)
    resp = raw_client.post("/auth/login", json={"email": "a@example.com", "password": "wrong"})
    assert resp.status_code == 401


def test_login_unknown_email(raw_client):
    resp = raw_client.post("/auth/login", json={"email": "nobody@example.com", "password": "password123"})
    assert resp.status_code == 401


def test_me_returns_current_user(raw_client):
    token = _register(raw_client).json()["access_token"]
    resp = raw_client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 200
    assert resp.json()["email"] == "a@example.com"
    assert "password_hash" not in resp.json()


def test_me_requires_auth(raw_client):
    assert raw_client.get("/auth/me").status_code == 401


def test_invalid_token_rejected(raw_client):
    resp = raw_client.get("/auth/me", headers={"Authorization": "Bearer garbage.token.here"})
    assert resp.status_code == 401


def test_refresh_issues_new_tokens(raw_client):
    refresh = _register(raw_client).json()["refresh_token"]
    resp = raw_client.post("/auth/refresh", json={"refresh_token": refresh})
    assert resp.status_code == 200
    assert resp.json()["access_token"]


def test_refresh_rejects_access_token(raw_client):
    # An access token must not be usable as a refresh token.
    access = _register(raw_client).json()["access_token"]
    resp = raw_client.post("/auth/refresh", json={"refresh_token": access})
    assert resp.status_code == 401


def test_refresh_rejects_garbage(raw_client):
    assert raw_client.post("/auth/refresh", json={"refresh_token": "nope"}).status_code == 401


def test_protected_route_requires_auth(raw_client):
    # Business endpoints reject unauthenticated requests.
    assert raw_client.get("/projects").status_code == 401


def test_expired_token_rejected(raw_client):
    from datetime import timedelta

    from app.core import security

    _register(raw_client)
    # Mint a token that expired an hour ago.
    expired = security._create_token("1", security.ACCESS_TOKEN_TYPE, timedelta(hours=-1))
    resp = raw_client.get("/auth/me", headers={"Authorization": f"Bearer {expired}"})
    assert resp.status_code == 401
