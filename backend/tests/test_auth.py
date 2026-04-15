import pytest
from httpx import AsyncClient

pytestmark = pytest.mark.asyncio


async def test_register_success(client: AsyncClient):
    res = await client.post(
        "/api/v1/auth/register",
        json={"email": "new@test.com", "password": "NewPass1", "name": "New User"},
    )
    assert res.status_code == 201
    data = res.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["token_type"] == "bearer"


async def test_register_duplicate_email(client: AsyncClient):
    payload = {"email": "dup@test.com", "password": "Dup12345", "name": "Dup"}
    await client.post("/api/v1/auth/register", json=payload)
    res = await client.post("/api/v1/auth/register", json=payload)
    assert res.status_code == 409
    assert "already exists" in res.json()["detail"].lower()


async def test_register_weak_password_no_digit(client: AsyncClient):
    res = await client.post(
        "/api/v1/auth/register",
        json={"email": "weak@test.com", "password": "NoDigits", "name": "W"},
    )
    assert res.status_code == 422


async def test_register_weak_password_too_short(client: AsyncClient):
    res = await client.post(
        "/api/v1/auth/register",
        json={"email": "short@test.com", "password": "Ab1", "name": "S"},
    )
    assert res.status_code == 422


async def test_register_invalid_email(client: AsyncClient):
    res = await client.post(
        "/api/v1/auth/register",
        json={"email": "not-an-email", "password": "Good1234", "name": "X"},
    )
    assert res.status_code == 422


async def test_login_success(client: AsyncClient, auth_headers: dict):
    res = await client.post(
        "/api/v1/auth/login",
        json={"email": "test@crosssync.dev", "password": "Test1234"},
    )
    assert res.status_code == 200
    assert "access_token" in res.json()


async def test_login_wrong_password(client: AsyncClient):
    res = await client.post(
        "/api/v1/auth/login",
        json={"email": "test@crosssync.dev", "password": "WrongPass9"},
    )
    assert res.status_code == 401


async def test_login_unknown_email(client: AsyncClient):
    res = await client.post(
        "/api/v1/auth/login",
        json={"email": "nobody@test.com", "password": "Test1234"},
    )
    assert res.status_code == 401


async def test_get_me(client: AsyncClient, auth_headers: dict):
    res = await client.get("/api/v1/auth/me", headers=auth_headers)
    assert res.status_code == 200
    data = res.json()
    assert data["email"] == "test@crosssync.dev"
    assert data["name"] == "Test User"
    assert data["is_active"] is True


async def test_get_me_no_token(client: AsyncClient):
    res = await client.get("/api/v1/auth/me")
    assert res.status_code == 401


async def test_get_me_invalid_token(client: AsyncClient):
    res = await client.get(
        "/api/v1/auth/me", headers={"Authorization": "Bearer invalid.token.here"}
    )
    assert res.status_code == 401


async def test_refresh_token(client: AsyncClient):
    reg = await client.post(
        "/api/v1/auth/register",
        json={"email": "refresh@test.com", "password": "Refresh1", "name": "R"},
    )
    refresh_token = reg.json()["refresh_token"]
    res = await client.post(
        "/api/v1/auth/refresh", json={"refresh_token": refresh_token}
    )
    assert res.status_code == 200
    assert "access_token" in res.json()


async def test_refresh_with_access_token_fails(client: AsyncClient, auth_headers: dict):
    # Access tokens must not be usable as refresh tokens
    bad_token = auth_headers["Authorization"].split(" ")[1]
    res = await client.post(
        "/api/v1/auth/refresh", json={"refresh_token": bad_token}
    )
    assert res.status_code == 401
