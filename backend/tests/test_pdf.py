"""
PDF endpoint tests.
Uses a real minimal PDF created in-memory via PyMuPDF so no fixture files needed.
"""
import io
import pytest
import fitz
from httpx import AsyncClient

pytestmark = pytest.mark.asyncio


def _make_pdf(text: str = "Hello CrossSync PDF test") -> bytes:
    """Create a minimal valid PDF in memory."""
    doc = fitz.open()
    page = doc.new_page()
    page.insert_text((72, 72), text, fontsize=12)
    buf = io.BytesIO()
    doc.save(buf)
    doc.close()
    return buf.getvalue()


async def test_upload_pdf(client: AsyncClient, auth_headers: dict):
    pdf_bytes = _make_pdf("Test document content")
    res = await client.post(
        "/api/v1/pdf/upload",
        files={"file": ("test.pdf", pdf_bytes, "application/pdf")},
        headers=auth_headers,
    )
    assert res.status_code == 201
    data = res.json()
    assert data["filename"] == "test.pdf"
    assert data["page_count"] == 1
    assert data["file_size"] > 0
    assert data["is_summarized"] is False


async def test_upload_non_pdf_rejected(client: AsyncClient, auth_headers: dict):
    res = await client.post(
        "/api/v1/pdf/upload",
        files={"file": ("evil.exe", b"MZ\x90\x00", "application/octet-stream")},
        headers=auth_headers,
    )
    assert res.status_code == 422
    assert "PDF" in res.json()["detail"]


async def test_list_documents(client: AsyncClient, auth_headers: dict):
    pdf_bytes = _make_pdf()
    await client.post(
        "/api/v1/pdf/upload",
        files={"file": ("list_test.pdf", pdf_bytes, "application/pdf")},
        headers=auth_headers,
    )
    res = await client.get("/api/v1/pdf/", headers=auth_headers)
    assert res.status_code == 200
    assert len(res.json()) >= 1


async def test_get_document(client: AsyncClient, auth_headers: dict):
    pdf_bytes = _make_pdf()
    upload_res = await client.post(
        "/api/v1/pdf/upload",
        files={"file": ("get_test.pdf", pdf_bytes, "application/pdf")},
        headers=auth_headers,
    )
    doc_id = upload_res.json()["id"]
    res = await client.get(f"/api/v1/pdf/{doc_id}", headers=auth_headers)
    assert res.status_code == 200
    assert res.json()["id"] == doc_id


async def test_get_document_wrong_user(
    client: AsyncClient, auth_headers: dict, second_user_headers: dict
):
    pdf_bytes = _make_pdf()
    upload_res = await client.post(
        "/api/v1/pdf/upload",
        files={"file": ("private.pdf", pdf_bytes, "application/pdf")},
        headers=auth_headers,
    )
    doc_id = upload_res.json()["id"]
    res = await client.get(f"/api/v1/pdf/{doc_id}", headers=second_user_headers)
    assert res.status_code == 404


async def test_merge_two_pdfs(client: AsyncClient, auth_headers: dict):
    pdf_a = _make_pdf("Document A page 1")
    pdf_b = _make_pdf("Document B page 1")

    id_a = (
        await client.post(
            "/api/v1/pdf/upload",
            files={"file": ("a.pdf", pdf_a, "application/pdf")},
            headers=auth_headers,
        )
    ).json()["id"]
    id_b = (
        await client.post(
            "/api/v1/pdf/upload",
            files={"file": ("b.pdf", pdf_b, "application/pdf")},
            headers=auth_headers,
        )
    ).json()["id"]

    res = await client.post(
        "/api/v1/pdf/merge",
        json={
            "document_ids": [id_a, id_b],
            "output_filename": "merged.pdf",
        },
        headers=auth_headers,
    )
    assert res.status_code == 201
    data = res.json()
    assert data["filename"] == "merged.pdf"
    assert data["page_count"] == 2  # 1 page each


async def test_merge_single_document_rejected(client: AsyncClient, auth_headers: dict):
    pdf_bytes = _make_pdf()
    doc_id = (
        await client.post(
            "/api/v1/pdf/upload",
            files={"file": ("single.pdf", pdf_bytes, "application/pdf")},
            headers=auth_headers,
        )
    ).json()["id"]
    res = await client.post(
        "/api/v1/pdf/merge",
        json={"document_ids": [doc_id]},
        headers=auth_headers,
    )
    assert res.status_code == 422


async def test_merge_other_users_document_rejected(
    client: AsyncClient, auth_headers: dict, second_user_headers: dict
):
    pdf_bytes = _make_pdf()
    other_id = (
        await client.post(
            "/api/v1/pdf/upload",
            files={"file": ("other.pdf", pdf_bytes, "application/pdf")},
            headers=second_user_headers,
        )
    ).json()["id"]
    own_id = (
        await client.post(
            "/api/v1/pdf/upload",
            files={"file": ("own.pdf", pdf_bytes, "application/pdf")},
            headers=auth_headers,
        )
    ).json()["id"]

    res = await client.post(
        "/api/v1/pdf/merge",
        json={"document_ids": [own_id, other_id]},
        headers=auth_headers,
    )
    assert res.status_code == 404


async def test_delete_document(client: AsyncClient, auth_headers: dict):
    pdf_bytes = _make_pdf()
    doc_id = (
        await client.post(
            "/api/v1/pdf/upload",
            files={"file": ("del.pdf", pdf_bytes, "application/pdf")},
            headers=auth_headers,
        )
    ).json()["id"]
    res = await client.delete(f"/api/v1/pdf/{doc_id}", headers=auth_headers)
    assert res.status_code == 204
    get_res = await client.get(f"/api/v1/pdf/{doc_id}", headers=auth_headers)
    assert get_res.status_code == 404


async def test_summary_no_api_key(client: AsyncClient, auth_headers: dict):
    """When ANTHROPIC_API_KEY is empty, /summary returns 503."""
    pdf_bytes = _make_pdf("Summary test")
    doc_id = (
        await client.post(
            "/api/v1/pdf/upload",
            files={"file": ("summary.pdf", pdf_bytes, "application/pdf")},
            headers=auth_headers,
        )
    ).json()["id"]
    res = await client.get(f"/api/v1/pdf/{doc_id}/summary", headers=auth_headers)
    # In test env ANTHROPIC_API_KEY is empty, so expect 503
    assert res.status_code == 503


async def test_ask_pdf_no_api_key(client: AsyncClient, auth_headers: dict):
    """When ANTHROPIC_API_KEY is empty, /ask returns 503."""
    pdf_bytes = _make_pdf("Ask test document")
    doc_id = (
        await client.post(
            "/api/v1/pdf/upload",
            files={"file": ("ask.pdf", pdf_bytes, "application/pdf")},
            headers=auth_headers,
        )
    ).json()["id"]
    res = await client.post(
        f"/api/v1/pdf/{doc_id}/ask",
        json={"question": "What is this document about?"},
        headers=auth_headers,
    )
    assert res.status_code == 503
