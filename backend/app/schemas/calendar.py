from pydantic import BaseModel, field_validator
from datetime import datetime
from typing import Optional
import re


# ── Calendar ──────────────────────────────────────────────────────────────────

class CalendarCreate(BaseModel):
    name: str
    color: str = "#3B82F6"
    is_default: bool = False

    @field_validator("color")
    @classmethod
    def valid_hex_color(cls, v: str) -> str:
        if not re.match(r"^#[0-9A-Fa-f]{6}$", v):
            raise ValueError("Color must be a valid hex color (e.g. #3B82F6)")
        return v


class CalendarUpdate(BaseModel):
    name: Optional[str] = None
    color: Optional[str] = None
    is_default: Optional[bool] = None

    @field_validator("color")
    @classmethod
    def valid_hex_color(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and not re.match(r"^#[0-9A-Fa-f]{6}$", v):
            raise ValueError("Color must be a valid hex color (e.g. #3B82F6)")
        return v


class CalendarResponse(BaseModel):
    id: str
    user_id: str
    name: str
    color: str
    is_default: bool
    created_at: datetime

    model_config = {"from_attributes": True}


# ── Event ─────────────────────────────────────────────────────────────────────

class EventCreate(BaseModel):
    title: str
    description: Optional[str] = None
    start_time: datetime
    end_time: datetime
    recurrence_rule: Optional[str] = None
    location: Optional[str] = None
    color: Optional[str] = None
    is_all_day: bool = False

    @field_validator("end_time")
    @classmethod
    def end_after_start(cls, v: datetime, info) -> datetime:
        start = info.data.get("start_time")
        if start and v <= start:
            raise ValueError("end_time must be after start_time")
        return v


class EventUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    recurrence_rule: Optional[str] = None
    location: Optional[str] = None
    color: Optional[str] = None
    is_all_day: Optional[bool] = None


class EventResponse(BaseModel):
    id: str
    calendar_id: str
    title: str
    description: Optional[str] = None
    start_time: datetime
    end_time: datetime
    recurrence_rule: Optional[str] = None
    location: Optional[str] = None
    color: Optional[str] = None
    is_all_day: bool
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
