from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_
from datetime import datetime
from typing import Optional

from app.core.database import get_db
from app.api.deps import get_current_user
from app.models.user import User
from app.models.calendar import Calendar, Event
from app.schemas.calendar import (
    CalendarCreate,
    CalendarUpdate,
    CalendarResponse,
    EventCreate,
    EventUpdate,
    EventResponse,
)

router = APIRouter(prefix="/calendar", tags=["calendar"])


# ── Calendars ──────────────────────────────────────────────────────────────────

@router.get("/", response_model=list[CalendarResponse])
async def list_calendars(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Calendar).where(Calendar.user_id == current_user.id)
    )
    return result.scalars().all()


@router.post("/", response_model=CalendarResponse, status_code=status.HTTP_201_CREATED)
async def create_calendar(
    payload: CalendarCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # If this calendar is set as default, unset others
    if payload.is_default:
        existing = await db.execute(
            select(Calendar).where(
                and_(Calendar.user_id == current_user.id, Calendar.is_default == True)  # noqa: E712
            )
        )
        for cal in existing.scalars().all():
            cal.is_default = False

    calendar = Calendar(user_id=current_user.id, **payload.model_dump())
    db.add(calendar)
    await db.commit()
    await db.refresh(calendar)
    return calendar


@router.get("/{calendar_id}", response_model=CalendarResponse)
async def get_calendar(
    calendar_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Calendar).where(
            and_(Calendar.id == calendar_id, Calendar.user_id == current_user.id)
        )
    )
    calendar = result.scalar_one_or_none()
    if not calendar:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Calendar not found")
    return calendar


@router.patch("/{calendar_id}", response_model=CalendarResponse)
async def update_calendar(
    calendar_id: str,
    payload: CalendarUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Calendar).where(
            and_(Calendar.id == calendar_id, Calendar.user_id == current_user.id)
        )
    )
    calendar = result.scalar_one_or_none()
    if not calendar:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Calendar not found")

    update_data = payload.model_dump(exclude_unset=True)

    # If setting this calendar as default, unset others
    if update_data.get("is_default"):
        existing = await db.execute(
            select(Calendar).where(
                and_(
                    Calendar.user_id == current_user.id,
                    Calendar.is_default == True,  # noqa: E712
                    Calendar.id != calendar_id,
                )
            )
        )
        for cal in existing.scalars().all():
            cal.is_default = False

    for field, value in update_data.items():
        setattr(calendar, field, value)

    await db.commit()
    await db.refresh(calendar)
    return calendar


@router.delete("/{calendar_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_calendar(
    calendar_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Calendar).where(
            and_(Calendar.id == calendar_id, Calendar.user_id == current_user.id)
        )
    )
    calendar = result.scalar_one_or_none()
    if not calendar:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Calendar not found")
    if calendar.is_default:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot delete the default calendar",
        )
    await db.delete(calendar)
    await db.commit()


# ── Events ─────────────────────────────────────────────────────────────────────

@router.get("/events/range", response_model=list[EventResponse])
async def list_events_in_range(
    start: datetime = Query(..., description="Range start (ISO 8601)"),
    end: datetime = Query(..., description="Range end (ISO 8601)"),
    calendar_id: Optional[str] = Query(None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """List events that overlap with the given time range."""
    # Join calendars to verify ownership
    query = (
        select(Event)
        .join(Calendar, Event.calendar_id == Calendar.id)
        .where(
            and_(
                Calendar.user_id == current_user.id,
                Event.start_time < end,
                Event.end_time > start,
            )
        )
    )
    if calendar_id:
        query = query.where(Event.calendar_id == calendar_id)

    result = await db.execute(query)
    return result.scalars().all()


@router.post("/{calendar_id}/events", response_model=EventResponse, status_code=status.HTTP_201_CREATED)
async def create_event(
    calendar_id: str,
    payload: EventCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Verify calendar belongs to user
    cal_result = await db.execute(
        select(Calendar).where(
            and_(Calendar.id == calendar_id, Calendar.user_id == current_user.id)
        )
    )
    if not cal_result.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Calendar not found")

    event = Event(calendar_id=calendar_id, **payload.model_dump())
    db.add(event)
    await db.commit()
    await db.refresh(event)
    return event


@router.get("/{calendar_id}/events/{event_id}", response_model=EventResponse)
async def get_event(
    calendar_id: str,
    event_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Event)
        .join(Calendar, Event.calendar_id == Calendar.id)
        .where(
            and_(
                Event.id == event_id,
                Event.calendar_id == calendar_id,
                Calendar.user_id == current_user.id,
            )
        )
    )
    event = result.scalar_one_or_none()
    if not event:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")
    return event


@router.patch("/{calendar_id}/events/{event_id}", response_model=EventResponse)
async def update_event(
    calendar_id: str,
    event_id: str,
    payload: EventUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Event)
        .join(Calendar, Event.calendar_id == Calendar.id)
        .where(
            and_(
                Event.id == event_id,
                Event.calendar_id == calendar_id,
                Calendar.user_id == current_user.id,
            )
        )
    )
    event = result.scalar_one_or_none()
    if not event:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

    update_data = payload.model_dump(exclude_unset=True)

    # Validate time range if both are provided
    new_start = update_data.get("start_time", event.start_time)
    new_end = update_data.get("end_time", event.end_time)
    if new_end <= new_start:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="end_time must be after start_time",
        )

    for field, value in update_data.items():
        setattr(event, field, value)

    await db.commit()
    await db.refresh(event)
    return event


@router.delete("/{calendar_id}/events/{event_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_event(
    calendar_id: str,
    event_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Event)
        .join(Calendar, Event.calendar_id == Calendar.id)
        .where(
            and_(
                Event.id == event_id,
                Event.calendar_id == calendar_id,
                Calendar.user_id == current_user.id,
            )
        )
    )
    event = result.scalar_one_or_none()
    if not event:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

    await db.delete(event)
    await db.commit()
