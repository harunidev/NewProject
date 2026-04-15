import pytest
from httpx import AsyncClient

pytestmark = pytest.mark.asyncio


async def _create_task(client, headers, **kwargs):
    defaults = {"title": "Test Task", "priority": "medium"}
    defaults.update(kwargs)
    res = await client.post("/api/v1/tasks/", json=defaults, headers=headers)
    assert res.status_code == 201
    return res.json()


async def test_create_task_defaults(client: AsyncClient, auth_headers: dict):
    task = await _create_task(client, auth_headers, title="Default Task")
    assert task["status"] == "todo"
    assert task["priority"] == "medium"
    assert task["is_completed"] is False


async def test_create_task_with_all_fields(client: AsyncClient, auth_headers: dict):
    task = await _create_task(
        client,
        auth_headers,
        title="Full Task",
        description="Detailed description",
        priority="high",
        status="in_progress",
        due_date="2026-12-31T23:59:00Z",
    )
    assert task["title"] == "Full Task"
    assert task["priority"] == "high"
    assert task["status"] == "in_progress"
    assert task["description"] == "Detailed description"
    assert task["due_date"] is not None


async def test_list_tasks(client: AsyncClient, auth_headers: dict):
    await _create_task(client, auth_headers, title="List Task A")
    await _create_task(client, auth_headers, title="List Task B")
    res = await client.get("/api/v1/tasks/", headers=auth_headers)
    assert res.status_code == 200
    assert len(res.json()) >= 2


async def test_list_tasks_filter_by_status(client: AsyncClient, auth_headers: dict):
    await _create_task(client, auth_headers, title="Todo One", status="todo")
    await _create_task(client, auth_headers, title="Done One", status="done")
    res = await client.get("/api/v1/tasks/?status=todo", headers=auth_headers)
    assert res.status_code == 200
    assert all(t["status"] == "todo" for t in res.json())


async def test_list_tasks_filter_by_priority(client: AsyncClient, auth_headers: dict):
    await _create_task(client, auth_headers, title="High P", priority="high")
    res = await client.get("/api/v1/tasks/?priority=high", headers=auth_headers)
    assert res.status_code == 200
    assert all(t["priority"] == "high" for t in res.json())


async def test_get_task(client: AsyncClient, auth_headers: dict):
    task = await _create_task(client, auth_headers, title="Get Me")
    res = await client.get(f"/api/v1/tasks/{task['id']}", headers=auth_headers)
    assert res.status_code == 200
    assert res.json()["title"] == "Get Me"


async def test_get_task_not_found(client: AsyncClient, auth_headers: dict):
    res = await client.get("/api/v1/tasks/nonexistent-id", headers=auth_headers)
    assert res.status_code == 404


async def test_get_task_wrong_user(
    client: AsyncClient, auth_headers: dict, second_user_headers: dict
):
    task = await _create_task(client, auth_headers, title="Private Task")
    res = await client.get(f"/api/v1/tasks/{task['id']}", headers=second_user_headers)
    assert res.status_code == 404


async def test_update_task(client: AsyncClient, auth_headers: dict):
    task = await _create_task(client, auth_headers, title="Original")
    res = await client.patch(
        f"/api/v1/tasks/{task['id']}",
        json={"title": "Updated", "priority": "high"},
        headers=auth_headers,
    )
    assert res.status_code == 200
    assert res.json()["title"] == "Updated"
    assert res.json()["priority"] == "high"


async def test_update_status_to_done_sets_completed(
    client: AsyncClient, auth_headers: dict
):
    task = await _create_task(client, auth_headers, title="Will Complete")
    res = await client.patch(
        f"/api/v1/tasks/{task['id']}/status",
        json={"status": "done"},
        headers=auth_headers,
    )
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "done"
    assert data["is_completed"] is True


async def test_update_status_from_done_clears_completed(
    client: AsyncClient, auth_headers: dict
):
    task = await _create_task(client, auth_headers, title="Reopen", status="done")
    res = await client.patch(
        f"/api/v1/tasks/{task['id']}/status",
        json={"status": "todo"},
        headers=auth_headers,
    )
    assert res.status_code == 200
    assert res.json()["is_completed"] is False


async def test_status_cycle(client: AsyncClient, auth_headers: dict):
    task = await _create_task(client, auth_headers, title="Cycling")

    for status, expected_completed in [
        ("in_progress", False),
        ("done", True),
        ("todo", False),
    ]:
        res = await client.patch(
            f"/api/v1/tasks/{task['id']}/status",
            json={"status": status},
            headers=auth_headers,
        )
        assert res.status_code == 200
        assert res.json()["status"] == status
        assert res.json()["is_completed"] == expected_completed


async def test_create_subtask(client: AsyncClient, auth_headers: dict):
    parent = await _create_task(client, auth_headers, title="Parent")
    child = await _create_task(
        client, auth_headers, title="Child", parent_task_id=parent["id"]
    )
    assert child["parent_task_id"] == parent["id"]


async def test_list_subtasks(client: AsyncClient, auth_headers: dict):
    parent = await _create_task(client, auth_headers, title="Parent with Children")
    await _create_task(client, auth_headers, title="Sub 1", parent_task_id=parent["id"])
    await _create_task(client, auth_headers, title="Sub 2", parent_task_id=parent["id"])

    res = await client.get(
        f"/api/v1/tasks/{parent['id']}/subtasks", headers=auth_headers
    )
    assert res.status_code == 200
    assert len(res.json()) == 2


async def test_create_subtask_nonexistent_parent(
    client: AsyncClient, auth_headers: dict
):
    res = await client.post(
        "/api/v1/tasks/",
        json={"title": "Orphan", "parent_task_id": "nonexistent-id"},
        headers=auth_headers,
    )
    assert res.status_code == 404


async def test_delete_task(client: AsyncClient, auth_headers: dict):
    task = await _create_task(client, auth_headers, title="Delete Me")
    res = await client.delete(f"/api/v1/tasks/{task['id']}", headers=auth_headers)
    assert res.status_code == 204
    # Confirm it's gone
    get_res = await client.get(f"/api/v1/tasks/{task['id']}", headers=auth_headers)
    assert get_res.status_code == 404


async def test_tasks_isolated_between_users(
    client: AsyncClient, auth_headers: dict, second_user_headers: dict
):
    await _create_task(client, auth_headers, title="User1 Task")
    user1_tasks = (await client.get("/api/v1/tasks/", headers=auth_headers)).json()
    user2_tasks = (
        await client.get("/api/v1/tasks/", headers=second_user_headers)
    ).json()
    user1_ids = {t["id"] for t in user1_tasks}
    user2_ids = {t["id"] for t in user2_tasks}
    assert user1_ids.isdisjoint(user2_ids)


async def test_unauthorized_access(client: AsyncClient):
    res = await client.get("/api/v1/tasks/")
    assert res.status_code == 401
