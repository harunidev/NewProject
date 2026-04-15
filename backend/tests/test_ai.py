"""
AI endpoint tests — verify 503 behaviour when API key is absent,
and that endpoints are properly protected by auth.
"""
import pytest
from httpx import AsyncClient

pytestmark = pytest.mark.asyncio


async def test_suggest_slots_no_key(client: AsyncClient, auth_headers: dict):
    res = await client.post(
        "/api/v1/ai/calendar/suggest",
        json={"request": "Schedule a 1-hour review", "duration_minutes": 60},
        headers=auth_headers,
    )
    assert res.status_code == 503


async def test_suggest_slots_unauthenticated(client: AsyncClient):
    res = await client.post(
        "/api/v1/ai/calendar/suggest",
        json={"request": "Find me a slot"},
    )
    assert res.status_code == 401


async def test_weekly_summary_no_key(client: AsyncClient, auth_headers: dict):
    res = await client.get("/api/v1/ai/weekly-summary", headers=auth_headers)
    assert res.status_code == 503


async def test_weekly_summary_unauthenticated(client: AsyncClient):
    res = await client.get("/api/v1/ai/weekly-summary")
    assert res.status_code == 401
