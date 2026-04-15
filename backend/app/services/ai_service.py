"""
AI service using Anthropic Claude API.
Handles PDF summarization, Q&A, and calendar suggestions.
"""
import os
from typing import Optional
import anthropic

from app.core.config import settings


def _get_client() -> anthropic.Anthropic:
    api_key = settings.ANTHROPIC_API_KEY
    if not api_key:
        raise RuntimeError(
            "ANTHROPIC_API_KEY is not set. AI features require a valid API key."
        )
    return anthropic.Anthropic(api_key=api_key)


def summarize_pdf(text: str, filename: str) -> str:
    """
    Generate a concise bullet-point summary of PDF text content.
    """
    client = _get_client()
    prompt = (
        f"You are analyzing the document '{filename}'.\n\n"
        "Please provide a concise summary in bullet points covering:\n"
        "- Main topic/purpose\n"
        "- Key points (up to 7 bullets)\n"
        "- Important dates, numbers, or names if present\n"
        "- Any action items or conclusions\n\n"
        "Keep it brief and scannable.\n\n"
        f"Document content:\n{text[:40_000]}"
    )
    message = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=1024,
        messages=[{"role": "user", "content": prompt}],
    )
    return message.content[0].text


def ask_pdf(text: str, question: str, filename: str) -> str:
    """
    Answer a question about a PDF document's content.
    """
    client = _get_client()
    prompt = (
        f"You are a helpful assistant analyzing the document '{filename}'.\n\n"
        f"Answer the following question based ONLY on the document content provided.\n"
        f"If the answer is not in the document, say so clearly.\n\n"
        f"Question: {question}\n\n"
        f"Document content:\n{text[:40_000]}"
    )
    message = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=1024,
        messages=[{"role": "user", "content": prompt}],
    )
    return message.content[0].text


def suggest_calendar_slots(
    events_summary: str,
    request: str,
    duration_minutes: int = 60,
) -> str:
    """
    Suggest available time slots based on existing calendar events.
    """
    client = _get_client()
    prompt = (
        "You are a scheduling assistant. Based on the user's existing calendar events, "
        f"suggest 3 available time slots for a {duration_minutes}-minute meeting.\n\n"
        f"User request: {request}\n\n"
        f"Existing events this week:\n{events_summary}\n\n"
        "Provide 3 specific time slot suggestions with brief reasoning for each. "
        "Format as:\n1. [Day] [Time] — [Reason]\n2. ...\n3. ..."
    )
    message = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=512,
        messages=[{"role": "user", "content": prompt}],
    )
    return message.content[0].text


def generate_weekly_summary(
    events: list[dict],
    tasks_done: int,
    tasks_pending: int,
    tasks_overdue: int,
) -> str:
    """
    Generate a weekly productivity summary and suggestions.
    """
    client = _get_client()
    events_text = "\n".join(
        f"- {e.get('title')} ({e.get('start_time', '')[:10]})" for e in events[:20]
    )
    prompt = (
        "You are a productivity coach. Generate a brief weekly summary and 2-3 actionable suggestions.\n\n"
        f"This week's events ({len(events)} total):\n{events_text}\n\n"
        f"Tasks completed: {tasks_done}\n"
        f"Tasks still pending: {tasks_pending}\n"
        f"Overdue tasks: {tasks_overdue}\n\n"
        "Keep the summary under 150 words. Be encouraging but honest."
    )
    message = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=512,
        messages=[{"role": "user", "content": prompt}],
    )
    return message.content[0].text
