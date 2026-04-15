import pytest
from httpx import AsyncClient

pytestmark = pytest.mark.asyncio

# ── Calendar CRUD ──────────────────────────────────────────────────────────────

async def test_default_calendar_created_on_register(
    client: AsyncClient, auth_headers: dict
):
    res = await client.get("/api/v1/calendar/", headers=auth_headers)
    assert res.status_code == 200
    cals = res.json()
    assert len(cals) >= 1
    default = next((c for c in cals if c["is_default"]), None)
    assert default is not None


async def test_create_calendar(client: AsyncClient, auth_headers: dict):
    res = await client.post(
        "/api/v1/calendar/",
        json={"name": "Work", "color": "#EF4444"},
        headers=auth_headers,
    )
    assert res.status_code == 201
    data = res.json()
    assert data["name"] == "Work"
    assert data["color"] == "#EF4444"
    assert data["is_default"] is False


async def test_create_calendar_invalid_color(client: AsyncClient, auth_headers: dict):
    res = await client.post(
        "/api/v1/calendar/",
        json={"name": "Bad", "color": "red"},
        headers=auth_headers,
    )
    assert res.status_code == 422


async def test_get_calendar(client: AsyncClient, auth_headers: dict):
    create_res = await client.post(
        "/api/v1/calendar/",
        json={"name": "GetMe", "color": "#10B981"},
        headers=auth_headers,
    )
    cal_id = create_res.json()["id"]
    res = await client.get(f"/api/v1/calendar/{cal_id}", headers=auth_headers)
    assert res.status_code == 200
    assert res.json()["name"] == "GetMe"


async def test_get_calendar_wrong_user(
    client: AsyncClient, auth_headers: dict, second_user_headers: dict
):
    create_res = await client.post(
        "/api/v1/calendar/",
        json={"name": "Private", "color": "#6366F1"},
        headers=auth_headers,
    )
    cal_id = create_res.json()["id"]
    res = await client.get(f"/api/v1/calendar/{cal_id}", headers=second_user_headers)
    assert res.status_code == 404


async def test_update_calendar(client: AsyncClient, auth_headers: dict):
    create_res = await client.post(
        "/api/v1/calendar/", json={"name": "Old", "color": "#000000"}, headers=auth_headers
    )
    cal_id = create_res.json()["id"]
    res = await client.patch(
        f"/api/v1/calendar/{cal_id}", json={"name": "New"}, headers=auth_headers
    )
    assert res.status_code == 200
    assert res.json()["name"] == "New"


async def test_delete_default_calendar_blocked(
    client: AsyncClient, auth_headers: dict
):
    cals = (await client.get("/api/v1/calendar/", headers=auth_headers)).json()
    default_id = next(c["id"] for c in cals if c["is_default"])
    res = await client.delete(f"/api/v1/calendar/{default_id}", headers=auth_headers)
    assert res.status_code == 400


async def test_delete_non_default_calendar(client: AsyncClient, auth_headers: dict):
    create_res = await client.post(
        "/api/v1/calendar/", json={"name": "Delete Me", "color": "#FF0000"}, headers=auth_headers
    )
    cal_id = create_res.json()["id"]
    res = await client.delete(f"/api/v1/calendar/{cal_id}", headers=auth_headers)
    assert res.status_code == 204


# ── Events ─────────────────────────────────────────────────────────────────────

async def _default_calendar_id(client, headers):
    cals = (await client.get("/api/v1/calendar/", headers=headers)).json()
    return next(c["id"] for c in cals if c["is_default"])


async def test_create_event(client: AsyncClient, auth_headers: dict):
    cal_id = await _default_calendar_id(client, auth_headers)
    res = await client.post(
        f"/api/v1/calendar/{cal_id}/events",
        json={
            "title": "Team Meeting",
            "start_time": "2026-05-10T10:00:00Z",
            "end_time": "2026-05-10T11:00:00Z",
            "location": "Zoom",
        },
        headers=auth_headers,
    )
    assert res.status_code == 201
    data = res.json()
    assert data["title"] == "Team Meeting"
    assert data["location"] == "Zoom"


async def test_create_event_end_before_start(client: AsyncClient, auth_headers: dict):
    cal_id = await _default_calendar_id(client, auth_headers)
    res = await client.post(
        f"/api/v1/calendar/{cal_id}/events",
        json={
            "title": "Bad",
            "start_time": "2026-05-10T11:00:00Z",
            "end_time": "2026-05-10T10:00:00Z",
        },
        headers=auth_headers,
    )
    assert res.status_code == 422


async def test_events_in_range(client: AsyncClient, auth_headers: dict):
    cal_id = await _default_calendar_id(client, auth_headers)
    # Create two events, one inside range, one outside
    await client.post(
        f"/api/v1/calendar/{cal_id}/events",
        json={
            "title": "Inside Range",
            "start_time": "2026-06-15T09:00:00Z",
            "end_time": "2026-06-15T10:00:00Z",
        },
        headers=auth_headers,
    )
    await client.post(
        f"/api/v1/calendar/{cal_id}/events",
        json={
            "title": "Outside Range",
            "start_time": "2026-07-01T09:00:00Z",
            "end_time": "2026-07-01T10:00:00Z",
        },
        headers=auth_headers,
    )
    res = await client.get(
        "/api/v1/calendar/events/range",
        params={"start": "2026-06-14T00:00:00Z", "end": "2026-06-16T00:00:00Z"},
        headers=auth_headers,
    )
    assert res.status_code == 200
    titles = [e["title"] for e in res.json()]
    assert "Inside Range" in titles
    assert "Outside Range" not in titles


async def test_update_event(client: AsyncClient, auth_headers: dict):
    cal_id = await _default_calendar_id(client, auth_headers)
    create_res = await client.post(
        f"/api/v1/calendar/{cal_id}/events",
        json={
            "title": "Original Title",
            "start_time": "2026-05-20T14:00:00Z",
            "end_time": "2026-05-20T15:00:00Z",
        },
        headers=auth_headers,
    )
    ev_id = create_res.json()["id"]
    res = await client.patch(
        f"/api/v1/calendar/{cal_id}/events/{ev_id}",
        json={"title": "Updated Title"},
        headers=auth_headers,
    )
    assert res.status_code == 200
    assert res.json()["title"] == "Updated Title"


async def test_update_event_invalid_times(client: AsyncClient, auth_headers: dict):
    cal_id = await _default_calendar_id(client, auth_headers)
    create_res = await client.post(
        f"/api/v1/calendar/{cal_id}/events",
        json={
            "title": "Time Test",
            "start_time": "2026-05-25T14:00:00Z",
            "end_time": "2026-05-25T15:00:00Z",
        },
        headers=auth_headers,
    )
    ev_id = create_res.json()["id"]
    res = await client.patch(
        f"/api/v1/calendar/{cal_id}/events/{ev_id}",
        json={"end_time": "2026-05-25T13:00:00Z"},
        headers=auth_headers,
    )
    assert res.status_code == 422


async def test_delete_event(client: AsyncClient, auth_headers: dict):
    cal_id = await _default_calendar_id(client, auth_headers)
    create_res = await client.post(
        f"/api/v1/calendar/{cal_id}/events",
        json={
            "title": "Deletable",
            "start_time": "2026-05-30T10:00:00Z",
            "end_time": "2026-05-30T11:00:00Z",
        },
        headers=auth_headers,
    )
    ev_id = create_res.json()["id"]
    res = await client.delete(
        f"/api/v1/calendar/{cal_id}/events/{ev_id}", headers=auth_headers
    )
    assert res.status_code == 204


async def test_get_event_wrong_user(
    client: AsyncClient, auth_headers: dict, second_user_headers: dict
):
    cal_id = await _default_calendar_id(client, auth_headers)
    create_res = await client.post(
        f"/api/v1/calendar/{cal_id}/events",
        json={
            "title": "Private Event",
            "start_time": "2026-06-01T10:00:00Z",
            "end_time": "2026-06-01T11:00:00Z",
        },
        headers=auth_headers,
    )
    ev_id = create_res.json()["id"]
    other_cal_id = await _default_calendar_id(client, second_user_headers)
    res = await client.get(
        f"/api/v1/calendar/{other_cal_id}/events/{ev_id}",
        headers=second_user_headers,
    )
    assert res.status_code == 404
