"""
Unit tests for the PDF service layer (no HTTP, no database).
"""
import io
import os
import pytest
import fitz

from app.services.pdf_service import (
    extract_text,
    get_page_count,
    merge_pdfs,
    extract_pages,
    delete_file,
    get_storage_path,
)


def _tmp_pdf(tmp_path, name: str, pages: int = 1, text: str = "Test") -> str:
    doc = fitz.open()
    for i in range(pages):
        page = doc.new_page()
        page.insert_text((72, 72), f"{text} — page {i + 1}", fontsize=12)
    path = str(tmp_path / name)
    doc.save(path)
    doc.close()
    return path


def test_get_page_count(tmp_path):
    path = _tmp_pdf(tmp_path, "three.pdf", pages=3)
    assert get_page_count(path) == 3


def test_extract_text(tmp_path):
    path = _tmp_pdf(tmp_path, "extract.pdf", text="CrossSync")
    text = extract_text(path)
    assert "CrossSync" in text


def test_extract_text_respects_max_chars(tmp_path):
    path = _tmp_pdf(tmp_path, "big.pdf", pages=5, text="A" * 200)
    text = extract_text(path, max_chars=100)
    assert len(text) <= 100


def test_merge_pdfs(tmp_path):
    a = _tmp_pdf(tmp_path, "a.pdf", pages=2)
    b = _tmp_pdf(tmp_path, "b.pdf", pages=3)
    out = str(tmp_path / "merged.pdf")
    total = merge_pdfs([a, b], out)
    assert total == 5
    assert get_page_count(out) == 5


def test_extract_specific_pages(tmp_path):
    src = _tmp_pdf(tmp_path, "src.pdf", pages=5)
    out = str(tmp_path / "extracted.pdf")
    count = extract_pages(src, out, page_numbers=[0, 2, 4])
    assert count == 3
    assert get_page_count(out) == 3


def test_extract_pages_out_of_range_skipped(tmp_path):
    src = _tmp_pdf(tmp_path, "small.pdf", pages=2)
    out = str(tmp_path / "safe.pdf")
    count = extract_pages(src, out, page_numbers=[0, 99])
    assert count == 1  # only page 0 is valid


def test_delete_file(tmp_path):
    path = _tmp_pdf(tmp_path, "todelete.pdf")
    assert os.path.exists(path)
    delete_file(path)
    assert not os.path.exists(path)


def test_delete_nonexistent_file_no_error(tmp_path):
    # Should not raise
    delete_file(str(tmp_path / "ghost.pdf"))
