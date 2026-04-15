-- CrossSync — Supabase / PostgreSQL Schema
-- Run this in Supabase SQL Editor to set up production database

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── Users ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email       VARCHAR(255) NOT NULL UNIQUE,
    hashed_password VARCHAR(255) NOT NULL,
    name        VARCHAR(100) NOT NULL,
    avatar_url  VARCHAR(500),
    is_active   BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- ── Calendars ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS calendars (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name        VARCHAR(100) NOT NULL,
    color       VARCHAR(7) NOT NULL DEFAULT '#3B82F6',
    is_default  BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_calendars_user_id ON calendars(user_id);

-- Ensure only one default calendar per user
CREATE UNIQUE INDEX IF NOT EXISTS idx_calendars_one_default
    ON calendars(user_id) WHERE is_default = TRUE;

-- ── Events ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS events (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    calendar_id     UUID NOT NULL REFERENCES calendars(id) ON DELETE CASCADE,
    title           VARCHAR(200) NOT NULL,
    description     TEXT,
    start_time      TIMESTAMPTZ NOT NULL,
    end_time        TIMESTAMPTZ NOT NULL,
    recurrence_rule VARCHAR(500),
    location        VARCHAR(300),
    color           VARCHAR(7),
    is_all_day      BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_event_times CHECK (end_time > start_time)
);

CREATE INDEX IF NOT EXISTS idx_events_calendar_id ON events(calendar_id);
CREATE INDEX IF NOT EXISTS idx_events_time_range  ON events(start_time, end_time);

-- ── Tasks ─────────────────────────────────────────────────────────────────────
CREATE TYPE task_status   AS ENUM ('todo', 'in_progress', 'done');
CREATE TYPE task_priority AS ENUM ('low', 'medium', 'high');

CREATE TABLE IF NOT EXISTS tasks (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title           VARCHAR(200) NOT NULL,
    description     TEXT,
    status          task_status   NOT NULL DEFAULT 'todo',
    priority        task_priority NOT NULL DEFAULT 'medium',
    due_date        TIMESTAMPTZ,
    is_completed    BOOLEAN NOT NULL DEFAULT FALSE,
    event_id        UUID REFERENCES events(id) ON DELETE SET NULL,
    parent_task_id  UUID REFERENCES tasks(id)  ON DELETE CASCADE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tasks_user_id       ON tasks(user_id);
CREATE INDEX IF NOT EXISTS idx_tasks_status        ON tasks(user_id, status);
CREATE INDEX IF NOT EXISTS idx_tasks_parent        ON tasks(parent_task_id) WHERE parent_task_id IS NOT NULL;

-- ── Auto-update updated_at ────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_events_updated_at
    BEFORE UPDATE ON events
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_tasks_updated_at
    BEFORE UPDATE ON tasks
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ── Row Level Security (Supabase) ─────────────────────────────────────────────
ALTER TABLE users      ENABLE ROW LEVEL SECURITY;
ALTER TABLE calendars  ENABLE ROW LEVEL SECURITY;
ALTER TABLE events     ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks      ENABLE ROW LEVEL SECURITY;

-- Users can only read/write their own row
CREATE POLICY "users_own_row" ON users
    USING (id = auth.uid());

-- Calendars belong to the authenticated user
CREATE POLICY "calendars_own" ON calendars
    USING (user_id = auth.uid());

-- Events are accessible through their calendar
CREATE POLICY "events_own" ON events
    USING (
        calendar_id IN (
            SELECT id FROM calendars WHERE user_id = auth.uid()
        )
    );

-- Tasks belong to the authenticated user
CREATE POLICY "tasks_own" ON tasks
    USING (user_id = auth.uid());
