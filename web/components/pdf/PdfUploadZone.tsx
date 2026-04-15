"use client";

import { useRef, useState } from "react";
import { Upload, FileText, X } from "lucide-react";
import { api } from "@/lib/api";
import { Button } from "@/components/ui/Button";
import { cn } from "@/lib/utils";
import type { PdfDocument } from "@/lib/types";

interface Props {
  onUploaded: (doc: PdfDocument) => void;
}

export function PdfUploadZone({ onUploaded }: Props) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [dragging, setDragging] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function upload(file: File) {
    if (!file.name.toLowerCase().endsWith(".pdf")) {
      setError("Only PDF files are accepted");
      return;
    }
    if (file.size > 50 * 1024 * 1024) {
      setError("File exceeds 50 MB limit");
      return;
    }

    setError(null);
    setUploading(true);
    try {
      const form = new FormData();
      form.append("file", file);
      const res = await api.post("/pdf/upload", form, {
        headers: { "Content-Type": "multipart/form-data" },
      });
      onUploaded(res.data as PdfDocument);
    } catch {
      setError("Upload failed. Please try again.");
    } finally {
      setUploading(false);
    }
  }

  return (
    <div
      onDragOver={(e) => { e.preventDefault(); setDragging(true); }}
      onDragLeave={() => setDragging(false)}
      onDrop={(e) => {
        e.preventDefault();
        setDragging(false);
        const file = e.dataTransfer.files[0];
        if (file) upload(file);
      }}
      className={cn(
        "border-2 border-dashed rounded-xl p-10 flex flex-col items-center gap-4 cursor-pointer transition-colors",
        dragging ? "border-blue-400 bg-blue-50" : "border-slate-200 hover:border-slate-300 hover:bg-slate-50"
      )}
      onClick={() => inputRef.current?.click()}
    >
      <input
        ref={inputRef}
        type="file"
        accept=".pdf"
        className="hidden"
        onChange={(e) => { const f = e.target.files?.[0]; if (f) upload(f); }}
      />

      {uploading ? (
        <div className="flex flex-col items-center gap-2">
          <div className="h-10 w-10 animate-spin rounded-full border-4 border-blue-500 border-t-transparent" />
          <p className="text-sm text-slate-500">Uploading…</p>
        </div>
      ) : (
        <>
          <div className="w-14 h-14 bg-blue-50 rounded-2xl flex items-center justify-center">
            <Upload size={24} className="text-blue-500" />
          </div>
          <div className="text-center">
            <p className="font-medium text-slate-700">Drop a PDF here or click to browse</p>
            <p className="text-sm text-slate-400 mt-1">Maximum file size: 50 MB</p>
          </div>
        </>
      )}

      {error && (
        <div className="flex items-center gap-2 bg-red-50 text-red-600 text-sm rounded-lg px-3 py-2 mt-2">
          <X size={14} />
          {error}
        </div>
      )}
    </div>
  );
}
