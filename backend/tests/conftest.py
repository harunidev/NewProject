"""
Shared pytest fixtures.
Uses an in-memory SQLite database so tests are fully isolated.
"""
import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession

from app.main import app
from app.core.database import Base, get_db
from app.models import user, calendar, task, pdf  # noqa: F401 — register models


TEST_DB_URL = "sqlite+aiosqlite:///:memory:"

test_engine = create_async_engine(TEST_DB_URL, connect_args={"check_same_thread": False})
TestSessionLocal = async_sessionmaker(test_engine, class_=AsyncSession, expire_on_commit=False)


async def override_get_db():
    async with TestSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


app.dependency_overrides[get_db] = override_get_db


@pytest_asyncio.fixture(scope="session", autouse=True)
async def create_tables():
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


@pytest_asyncio.fixture(scope="function")
async def client():
    """Per-test HTTP client (fresh for every test)."""
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as ac:
        yield ac


@pytest_asyncio.fixture(scope="session")
async def auth_headers():
    """Register a test user once per session and return Authorization headers."""
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as ac:
        res = await ac.post(
            "/api/v1/auth/register",
            json={"email": "test@crosssync.dev", "password": "Test1234", "name": "Test User"},
        )
        # If already registered (e.g. re-run), fall back to login
        if res.status_code == 409:
            res = await ac.post(
                "/api/v1/auth/login",
                json={"email": "test@crosssync.dev", "password": "Test1234"},
            )
        assert res.status_code in (200, 201)
        token = res.json()["access_token"]
        return {"Authorization": f"Bearer {token}"}


@pytest_asyncio.fixture(scope="session")
async def second_user_headers():
    """Second user for ownership isolation tests."""
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as ac:
        res = await ac.post(
            "/api/v1/auth/register",
            json={"email": "other@crosssync.dev", "password": "Other1234", "name": "Other User"},
        )
        if res.status_code == 409:
            res = await ac.post(
                "/api/v1/auth/login",
                json={"email": "other@crosssync.dev", "password": "Other1234"},
            )
        assert res.status_code in (200, 201)
        token = res.json()["access_token"]
        return {"Authorization": f"Bearer {token}"}
