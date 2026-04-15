import pytest
from httpx import AsyncClient

pytestmark = pytest.mark.asyncio


async def test_health_check(client: AsyncClient):
    res = await client.get("/health")
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "ok"
    assert "version" in data


async def test_openapi_docs_available(client: AsyncClient):
    res = await client.get("/docs")
    assert res.status_code == 200
