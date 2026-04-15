from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_
from typing import Optional

from app.core.database import get_db
from app.api.deps import get_current_user
from app.models.user import User
from app.models.task import Task, TaskStatus, TaskPriority
from app.schemas.task import TaskCreate, TaskUpdate, TaskStatusUpdate, TaskResponse

router = APIRouter(prefix="/tasks", tags=["tasks"])


@router.get("/", response_model=list[TaskResponse])
async def list_tasks(
    status: Optional[TaskStatus] = Query(None),
    priority: Optional[TaskPriority] = Query(None),
    parent_only: bool = Query(False, description="Return only top-level tasks"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    query = select(Task).where(Task.user_id == current_user.id)

    if status:
        query = query.where(Task.status == status.value)
    if priority:
        query = query.where(Task.priority == priority.value)
    if parent_only:
        query = query.where(Task.parent_task_id == None)  # noqa: E711

    query = query.order_by(Task.created_at.desc())
    result = await db.execute(query)
    return result.scalars().all()


@router.post("/", response_model=TaskResponse, status_code=status.HTTP_201_CREATED)
async def create_task(
    payload: TaskCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Validate parent task belongs to user
    if payload.parent_task_id:
        parent_result = await db.execute(
            select(Task).where(
                and_(
                    Task.id == payload.parent_task_id,
                    Task.user_id == current_user.id,
                )
            )
        )
        if not parent_result.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Parent task not found"
            )

    task = Task(user_id=current_user.id, **payload.model_dump())
    db.add(task)
    await db.commit()
    await db.refresh(task)
    return task


@router.get("/{task_id}", response_model=TaskResponse)
async def get_task(
    task_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Task).where(and_(Task.id == task_id, Task.user_id == current_user.id))
    )
    task = result.scalar_one_or_none()
    if not task:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Task not found")
    return task


@router.get("/{task_id}/subtasks", response_model=list[TaskResponse])
async def list_subtasks(
    task_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Verify parent belongs to user
    parent_result = await db.execute(
        select(Task).where(and_(Task.id == task_id, Task.user_id == current_user.id))
    )
    if not parent_result.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Task not found")

    result = await db.execute(
        select(Task).where(Task.parent_task_id == task_id).order_by(Task.created_at)
    )
    return result.scalars().all()


@router.patch("/{task_id}", response_model=TaskResponse)
async def update_task(
    task_id: str,
    payload: TaskUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Task).where(and_(Task.id == task_id, Task.user_id == current_user.id))
    )
    task = result.scalar_one_or_none()
    if not task:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Task not found")

    update_data = payload.model_dump(exclude_unset=True)

    # Auto-set is_completed when status transitions to done
    if update_data.get("status") == TaskStatus.DONE.value:
        update_data["is_completed"] = True
    elif update_data.get("status") in (TaskStatus.TODO.value, TaskStatus.IN_PROGRESS.value):
        update_data["is_completed"] = False

    for field, value in update_data.items():
        if hasattr(task, field):
            setattr(task, field, value if not hasattr(value, "value") else value.value)

    await db.commit()
    await db.refresh(task)
    return task


@router.patch("/{task_id}/status", response_model=TaskResponse)
async def update_task_status(
    task_id: str,
    payload: TaskStatusUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Lightweight endpoint for Kanban drag-and-drop status changes."""
    result = await db.execute(
        select(Task).where(and_(Task.id == task_id, Task.user_id == current_user.id))
    )
    task = result.scalar_one_or_none()
    if not task:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Task not found")

    task.status = payload.status.value
    task.is_completed = payload.status == TaskStatus.DONE

    await db.commit()
    await db.refresh(task)
    return task


@router.delete("/{task_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_task(
    task_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Task).where(and_(Task.id == task_id, Task.user_id == current_user.id))
    )
    task = result.scalar_one_or_none()
    if not task:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Task not found")

    await db.delete(task)
    await db.commit()
