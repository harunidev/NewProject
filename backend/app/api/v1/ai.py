from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_
from pydantic import BaseModel
from datetime import datetime, timedelta, timezone
from typing import Optional
import anthropic as _anthropic

from app.core.database import get_db
from app.api.deps import get_current_user
from app.models.user import User
from app.models.calendar import Calendar, Event
from app.models.task import Task, TaskStatus

router = APIRouter(prefix="/ai", tags=["ai"])

_AI_503 = HTTPException(
    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
    detail="AI features are not configured or the API key is invalid",
)


def _require_ai_key() -> None:
    from app.core.config import settings
    if not settings.ANTHROPIC_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="AI features are not configured (ANTHROPIC_API_KEY missing)",
        )


# ── Calendar slot suggestion ───────────────────────────────────────────────────

class CalendarSuggestRequest(BaseModel):
    request: str
    duration_minutes: int = 60


class CalendarSuggestResponse(BaseModel):
    suggestions: str


@router.post("/calendar/suggest", response_model=CalendarSuggestResponse)
async def suggest_slots(
    payload: CalendarSuggestRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Suggest free calendar slots using AI based on existing events."""
    _require_ai_key()

    # Fetch this week's events
    now = datetime.now(timezone.utc)
    week_start = now - timedelta(days=now.weekday())
    week_end = week_start + timedelta(days=7)

    result = await db.execute(
        select(Event)
        .join(Calendar, Event.calendar_id == Calendar.id)
        .where(
            and_(
                Calendar.user_id == current_user.id,
                Event.start_time >= week_start,
                Event.end_time <= week_end,
            )
        )
        .order_by(Event.start_time)
    )
    events = result.scalars().all()

    events_summary = "\n".join(
        f"- {e.title}: {e.start_time.strftime('%A %H:%M')} – {e.end_time.strftime('%H:%M')}"
        for e in events
    ) or "No events scheduled this week"

    from app.services.ai_service import suggest_calendar_slots
    try:
        suggestions = suggest_calendar_slots(
            events_summary, payload.request, payload.duration_minutes
        )
    except (_anthropic.AuthenticationError, RuntimeError):
        raise _AI_503
    return CalendarSuggestResponse(suggestions=suggestions)


# ── Weekly summary ─────────────────────────────────────────────────────────────

class WeeklySummaryResponse(BaseModel):
    summary: str
    stats: dict


@router.get("/weekly-summary", response_model=WeeklySummaryResponse)
async def weekly_summary(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Generate a weekly productivity summary using AI."""
    _require_ai_key()

    now = datetime.now(timezone.utc)
    week_start = now - timedelta(days=now.weekday())
    week_end = week_start + timedelta(days=7)

    # Fetch this week's events
    events_result = await db.execute(
        select(Event)
        .join(Calendar, Event.calendar_id == Calendar.id)
        .where(
            and_(
                Calendar.user_id == current_user.id,
                Event.start_time >= week_start,
                Event.end_time <= week_end,
            )
        )
    )
    events = events_result.scalars().all()

    # Fetch tasks stats
    tasks_result = await db.execute(
        select(Task).where(Task.user_id == current_user.id)
    )
    all_tasks = tasks_result.scalars().all()

    tasks_done = sum(1 for t in all_tasks if t.status == TaskStatus.DONE.value)
    tasks_pending = sum(1 for t in all_tasks if t.status != TaskStatus.DONE.value)
    tasks_overdue = sum(
        1
        for t in all_tasks
        if t.due_date
        and t.due_date < now
        and t.status != TaskStatus.DONE.value
    )

    events_list = [
        {"title": e.title, "start_time": e.start_time.isoformat()}
        for e in events
    ]

    from app.services.ai_service import generate_weekly_summary
    try:
        summary_text = generate_weekly_summary(
            events_list, tasks_done, tasks_pending, tasks_overdue
        )
    except (_anthropic.AuthenticationError, RuntimeError):
        raise _AI_503

    return WeeklySummaryResponse(
        summary=summary_text,
        stats={
            "events_this_week": len(events),
            "tasks_done": tasks_done,
            "tasks_pending": tasks_pending,
            "tasks_overdue": tasks_overdue,
        },
    )
