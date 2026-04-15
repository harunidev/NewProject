from pydantic import BaseModel
from datetime import datetime
from typing import Optional


class PdfDocumentResponse(BaseModel):
    id: str
    user_id: str
    filename: str
    page_count: int
    file_size: int
    summary: Optional[str] = None
    is_summarized: bool
    uploaded_at: datetime

    model_config = {"from_attributes": True}


class PdfAskRequest(BaseModel):
    question: str


class PdfAskResponse(BaseModel):
    answer: str
    document_id: str


class PdfMergeRequest(BaseModel):
    document_ids: list[str]
    output_filename: str = "merged.pdf"
