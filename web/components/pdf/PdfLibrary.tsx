"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { FileText, Trash2, Sparkles, MessageSquare, GitMerge } from "lucide-react";
import { format, parseISO } from "date-fns";
import { api } from "@/lib/api";
import { Button } from "@/components/ui/Button";
import { PdfUploadZone } from "./PdfUploadZone";
import { PdfAiPanel } from "./PdfAiPanel";
import { cn } from "@/lib/utils";
import type { PdfDocument } from "@/lib/types";

export function PdfLibrary() {
  const qc = useQueryClient();
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [aiTarget, setAiTarget] = useState<PdfDocument | null>(null);
  const [mergeLoading, setMergeLoading] = useState(false);

  const { data: docs = [], isLoading } = useQuery<PdfDocument[]>({
    queryKey: ["pdf-docs"],
    queryFn: () => api.get("/pdf/").then((r) => r.data),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => api.delete(`/pdf/${id}`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["pdf-docs"] }),
  });

  function toggleSelect(id: string) {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      next.has(id) ? next.delete(id) : next.add(id);
      return next;
    });
  }

  async function handleMerge() {
    if (selectedIds.size < 2) return;
    setMergeLoading(true);
    try {
      await api.post("/pdf/merge", {
        document_ids: Array.from(selectedIds),
        output_filename: `merged_${Date.now()}.pdf`,
      });
      qc.invalidateQueries({ queryKey: ["pdf-docs"] });
      setSelectedIds(new Set());
    } finally {
      setMergeLoading(false);
    }
  }

  return (
    <div className="flex flex-col h-full gap-6">
      <div className="flex items-center justify-between">
        <h2 className="text-xl font-bold text-slate-800">PDF Tools</h2>
        {selectedIds.size >= 2 && (
          <Button
            size="sm"
            onClick={handleMerge}
            loading={mergeLoading}
          >
            <GitMerge size={14} className="mr-1" />
            Merge {selectedIds.size} PDFs
          </Button>
        )}
      </div>

      <PdfUploadZone
        onUploaded={() => qc.invalidateQueries({ queryKey: ["pdf-docs"] })}
      />

      {isLoading ? (
        <div className="flex justify-center py-8">
          <div className="animate-spin h-8 w-8 rounded-full border-4 border-blue-500 border-t-transparent" />
        </div>
      ) : docs.length === 0 ? (
        <div className="text-center py-10 text-slate-400">
          <FileText size={40} className="mx-auto mb-3 opacity-40" />
          <p>No PDFs uploaded yet</p>
        </div>
      ) : (
        <div className="space-y-2">
          {docs.map((doc) => (
            <div
              key={doc.id}
              className={cn(
                "bg-white rounded-xl border p-4 flex items-start gap-4 transition-colors",
                selectedIds.has(doc.id) ? "border-blue-400 bg-blue-50" : "border-slate-200"
              )}
            >
              <button
                onClick={() => toggleSelect(doc.id)}
                className={cn(
                  "w-5 h-5 rounded border-2 flex-shrink-0 mt-0.5 transition-colors",
                  selectedIds.has(doc.id)
                    ? "bg-blue-500 border-blue-500"
                    : "border-slate-300"
                )}
              />

              <div className="w-10 h-10 bg-red-50 rounded-lg flex items-center justify-center flex-shrink-0">
                <FileText size={20} className="text-red-500" />
              </div>

              <div className="flex-1 min-w-0">
                <p className="font-medium text-slate-800 truncate">{doc.filename}</p>
                <p className="text-xs text-slate-400 mt-0.5">
                  {doc.page_count} page{doc.page_count !== 1 ? "s" : ""} ·{" "}
                  {(doc.file_size / 1024).toFixed(1)} KB ·{" "}
                  {format(parseISO(doc.uploaded_at), "MMM d, yyyy")}
                </p>
                {doc.is_summarized && doc.summary && (
                  <p className="text-xs text-slate-500 mt-1.5 line-clamp-2">{doc.summary}</p>
                )}
              </div>

              <div className="flex items-center gap-1 flex-shrink-0">
                <button
                  onClick={() => setAiTarget(doc)}
                  className="p-1.5 rounded-lg hover:bg-purple-50 text-purple-500 transition-colors"
                  title="AI Tools"
                >
                  <Sparkles size={16} />
                </button>
                <button
                  onClick={() => deleteMutation.mutate(doc.id)}
                  className="p-1.5 rounded-lg hover:bg-red-50 text-red-400 transition-colors"
                  title="Delete"
                >
                  <Trash2 size={16} />
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {aiTarget && (
        <PdfAiPanel
          doc={aiTarget}
          onClose={() => setAiTarget(null)}
        />
      )}
    </div>
  );
}
