import os
import uuid
import anthropic as _anthropic
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_

from app.core.database import get_db
from app.api.deps import get_current_user
from app.models.user import User
from app.models.pdf import PdfDocument

_AI_503 = HTTPException(
    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
    detail="AI features are not configured or the API key is invalid",
)
from app.schemas.pdf import (
    PdfDocumentResponse,
    PdfAskRequest,
    PdfAskResponse,
    PdfMergeRequest,
)
from app.services import pdf_service

router = APIRouter(prefix="/pdf", tags=["pdf"])

MAX_PDF_SIZE = 50 * 1024 * 1024  # 50 MB


@router.get("/", response_model=list[PdfDocumentResponse])
async def list_documents(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(PdfDocument)
        .where(PdfDocument.user_id == current_user.id)
        .order_by(PdfDocument.uploaded_at.desc())
    )
    return result.scalars().all()


@router.post(
    "/upload",
    response_model=PdfDocumentResponse,
    status_code=status.HTTP_201_CREATED,
)
async def upload_pdf(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if not file.filename or not file.filename.lower().endswith(".pdf"):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Only PDF files are accepted",
        )

    content = await file.read()
    if len(content) > MAX_PDF_SIZE:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="File exceeds 50 MB limit",
        )

    # Save to storage
    doc_id = str(uuid.uuid4())
    safe_name = f"{doc_id}.pdf"
    storage_path = pdf_service.get_storage_path(safe_name)
    with open(storage_path, "wb") as f:
        f.write(content)

    try:
        page_count = pdf_service.get_page_count(storage_path)
    except Exception:
        pdf_service.delete_file(storage_path)
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Could not read PDF file — file may be corrupted",
        )

    doc = PdfDocument(
        id=doc_id,
        user_id=current_user.id,
        filename=file.filename,
        storage_path=storage_path,
        page_count=page_count,
        file_size=len(content),
    )
    db.add(doc)
    await db.commit()
    await db.refresh(doc)
    return doc


@router.get("/{document_id}", response_model=PdfDocumentResponse)
async def get_document(
    document_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    doc = await _get_doc_or_404(document_id, current_user.id, db)
    return doc


@router.get("/{document_id}/summary", response_model=dict)
async def get_summary(
    document_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Return cached summary or generate one via Claude API.
    """
    doc = await _get_doc_or_404(document_id, current_user.id, db)

    if doc.is_summarized and doc.summary:
        return {"summary": doc.summary, "cached": True}

    if not settings_ai_key_present():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="AI features are not configured (ANTHROPIC_API_KEY missing)",
        )

    from app.services.ai_service import summarize_pdf

    text = pdf_service.extract_text(doc.storage_path)
    if not text.strip():
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="PDF contains no extractable text",
        )

    try:
        summary = summarize_pdf(text, doc.filename)
    except (_anthropic.AuthenticationError, RuntimeError):
        raise _AI_503
    doc.summary = summary
    doc.is_summarized = True
    await db.commit()

    return {"summary": summary, "cached": False}


@router.post("/{document_id}/ask", response_model=PdfAskResponse)
async def ask_pdf(
    document_id: str,
    payload: PdfAskRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Ask a question about the PDF content."""
    doc = await _get_doc_or_404(document_id, current_user.id, db)

    if not settings_ai_key_present():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="AI features are not configured (ANTHROPIC_API_KEY missing)",
        )

    from app.services.ai_service import ask_pdf as ai_ask

    text = pdf_service.extract_text(doc.storage_path)
    try:
        answer = ai_ask(text, payload.question, doc.filename)
    except (_anthropic.AuthenticationError, RuntimeError):
        raise _AI_503
    return PdfAskResponse(answer=answer, document_id=document_id)


@router.post("/merge", response_model=PdfDocumentResponse, status_code=status.HTTP_201_CREATED)
async def merge_pdfs(
    payload: PdfMergeRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Merge multiple PDF documents into one."""
    if len(payload.document_ids) < 2:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="At least 2 documents are required to merge",
        )

    # Fetch all documents and verify ownership
    docs = []
    for doc_id in payload.document_ids:
        doc = await _get_doc_or_404(doc_id, current_user.id, db)
        docs.append(doc)

    merged_id = str(uuid.uuid4())
    output_path = pdf_service.get_storage_path(f"{merged_id}.pdf")

    try:
        page_count = pdf_service.merge_pdfs(
            [d.storage_path for d in docs], output_path
        )
    except Exception as e:
        pdf_service.delete_file(output_path)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"PDF merge failed: {e}",
        )

    merged_doc = PdfDocument(
        id=merged_id,
        user_id=current_user.id,
        filename=payload.output_filename,
        storage_path=output_path,
        page_count=page_count,
        file_size=os.path.getsize(output_path),
    )
    db.add(merged_doc)
    await db.commit()
    await db.refresh(merged_doc)
    return merged_doc


@router.delete("/{document_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_document(
    document_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    doc = await _get_doc_or_404(document_id, current_user.id, db)
    pdf_service.delete_file(doc.storage_path)
    await db.delete(doc)
    await db.commit()


# ── Helpers ───────────────────────────────────────────────────────────────────

async def _get_doc_or_404(
    document_id: str, user_id: str, db: AsyncSession
) -> PdfDocument:
    result = await db.execute(
        select(PdfDocument).where(
            and_(
                PdfDocument.id == document_id,
                PdfDocument.user_id == user_id,
            )
        )
    )
    doc = result.scalar_one_or_none()
    if not doc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Document not found"
        )
    return doc


def settings_ai_key_present() -> bool:
    from app.core.config import settings
    return bool(settings.ANTHROPIC_API_KEY)
