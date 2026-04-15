"""
PDF processing service using PyMuPDF (fitz).
Handles text extraction, merging, and page counting.
"""
import os
import fitz  # PyMuPDF


STORAGE_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "storage")
os.makedirs(STORAGE_DIR, exist_ok=True)


def get_storage_path(filename: str) -> str:
    return os.path.join(STORAGE_DIR, filename)


def extract_text(file_path: str, max_chars: int = 50_000) -> str:
    """Extract text content from a PDF file."""
    doc = fitz.open(file_path)
    text_parts: list[str] = []
    total = 0
    for page in doc:
        page_text = page.get_text()
        text_parts.append(page_text)
        total += len(page_text)
        if total >= max_chars:
            break
    doc.close()
    return "\n".join(text_parts)[:max_chars]


def get_page_count(file_path: str) -> int:
    doc = fitz.open(file_path)
    count = doc.page_count
    doc.close()
    return count


def merge_pdfs(input_paths: list[str], output_path: str) -> int:
    """
    Merge multiple PDFs into a single file.
    Returns total page count of the merged document.
    """
    merged = fitz.open()
    for path in input_paths:
        with fitz.open(path) as src:
            merged.insert_pdf(src)
    merged.save(output_path)
    page_count = merged.page_count
    merged.close()
    return page_count


def extract_pages(
    input_path: str, output_path: str, page_numbers: list[int]
) -> int:
    """
    Extract specific pages (0-indexed) from a PDF into a new file.
    Returns page count of the new document.
    """
    src = fitz.open(input_path)
    new_doc = fitz.open()
    for page_num in page_numbers:
        if 0 <= page_num < src.page_count:
            new_doc.insert_pdf(src, from_page=page_num, to_page=page_num)
    new_doc.save(output_path)
    page_count = new_doc.page_count
    src.close()
    new_doc.close()
    return page_count


def delete_file(file_path: str) -> None:
    try:
        os.remove(file_path)
    except FileNotFoundError:
        pass
