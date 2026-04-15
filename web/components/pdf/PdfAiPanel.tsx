"use client";

import { useState } from "react";
import { X, Sparkles, Send, BookOpen } from "lucide-react";
import { api } from "@/lib/api";
import { Button } from "@/components/ui/Button";
import type { PdfDocument } from "@/lib/types";

interface Props {
  doc: PdfDocument;
  onClose: () => void;
}

interface Message {
  role: "user" | "assistant";
  content: string;
}

export function PdfAiPanel({ doc, onClose }: Props) {
  const [tab, setTab] = useState<"summary" | "chat">("summary");
  const [summary, setSummary] = useState(doc.summary ?? "");
  const [summaryLoading, setSummaryLoading] = useState(false);
  const [messages, setMessages] = useState<Message[]>([]);
  const [question, setQuestion] = useState("");
  const [chatLoading, setChatLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function fetchSummary() {
    setSummaryLoading(true);
    setError(null);
    try {
      const res = await api.get(`/pdf/${doc.id}/summary`);
      setSummary(res.data.summary);
    } catch (e: unknown) {
      const detail = (e as { response?: { data?: { detail?: string } } })?.response?.data?.detail;
      setError(detail ?? "Failed to generate summary");
    } finally {
      setSummaryLoading(false);
    }
  }

  async function sendQuestion() {
    if (!question.trim()) return;
    const userMsg: Message = { role: "user", content: question };
    setMessages((prev) => [...prev, userMsg]);
    setQuestion("");
    setChatLoading(true);
    setError(null);
    try {
      const res = await api.post(`/pdf/${doc.id}/ask`, { question: userMsg.content });
      setMessages((prev) => [
        ...prev,
        { role: "assistant", content: res.data.answer },
      ]);
    } catch (e: unknown) {
      const detail = (e as { response?: { data?: { detail?: string } } })?.response?.data?.detail;
      setError(detail ?? "Failed to get answer");
    } finally {
      setChatLoading(false);
    }
  }

  return (
    <div className="fixed inset-0 bg-black/40 flex items-end sm:items-center justify-center z-50 p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg flex flex-col max-h-[80vh]">
        {/* Header */}
        <div className="flex items-center gap-3 p-5 border-b border-slate-100">
          <div className="w-9 h-9 bg-purple-100 rounded-lg flex items-center justify-center">
            <Sparkles size={18} className="text-purple-600" />
          </div>
          <div className="flex-1 min-w-0">
            <p className="font-semibold text-sm text-slate-800 truncate">{doc.filename}</p>
            <p className="text-xs text-slate-400">AI Analysis</p>
          </div>
          <button onClick={onClose} className="p-1 rounded-lg hover:bg-slate-100 transition-colors">
            <X size={18} />
          </button>
        </div>

        {/* Tabs */}
        <div className="flex border-b border-slate-100">
          {(["summary", "chat"] as const).map((t) => (
            <button
              key={t}
              onClick={() => setTab(t)}
              className={`flex-1 py-2.5 text-sm font-medium transition-colors capitalize ${
                tab === t
                  ? "text-purple-600 border-b-2 border-purple-500"
                  : "text-slate-500 hover:text-slate-700"
              }`}
            >
              {t === "summary" ? "Summary" : "Ask Questions"}
            </button>
          ))}
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto p-5">
          {error && (
            <div className="bg-red-50 border border-red-200 text-red-600 text-sm rounded-lg p-3 mb-4">
              {error}
            </div>
          )}

          {tab === "summary" && (
            <div>
              {summary ? (
                <div className="prose prose-sm max-w-none text-slate-700 whitespace-pre-wrap">
                  {summary}
                </div>
              ) : (
                <div className="text-center py-8">
                  <BookOpen size={40} className="mx-auto text-slate-300 mb-3" />
                  <p className="text-slate-500 mb-4 text-sm">
                    Generate an AI summary of this document
                  </p>
                  <Button onClick={fetchSummary} loading={summaryLoading}>
                    <Sparkles size={14} className="mr-2" />
                    Generate Summary
                  </Button>
                </div>
              )}
            </div>
          )}

          {tab === "chat" && (
            <div className="space-y-3">
              {messages.length === 0 && (
                <p className="text-sm text-slate-400 text-center py-4">
                  Ask anything about this document
                </p>
              )}
              {messages.map((msg, i) => (
                <div
                  key={i}
                  className={`flex ${msg.role === "user" ? "justify-end" : "justify-start"}`}
                >
                  <div
                    className={`max-w-[85%] rounded-2xl px-4 py-2.5 text-sm ${
                      msg.role === "user"
                        ? "bg-blue-500 text-white rounded-br-sm"
                        : "bg-slate-100 text-slate-800 rounded-bl-sm"
                    }`}
                  >
                    {msg.content}
                  </div>
                </div>
              ))}
              {chatLoading && (
                <div className="flex justify-start">
                  <div className="bg-slate-100 rounded-2xl rounded-bl-sm px-4 py-3">
                    <div className="flex gap-1">
                      {[0, 1, 2].map((i) => (
                        <div
                          key={i}
                          className="w-2 h-2 bg-slate-400 rounded-full animate-bounce"
                          style={{ animationDelay: `${i * 0.15}s` }}
                        />
                      ))}
                    </div>
                  </div>
                </div>
              )}
            </div>
          )}
        </div>

        {/* Chat input */}
        {tab === "chat" && (
          <div className="p-4 border-t border-slate-100">
            <div className="flex gap-2">
              <input
                value={question}
                onChange={(e) => setQuestion(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && !e.shiftKey && sendQuestion()}
                placeholder="Ask a question about this document…"
                className="flex-1 border border-slate-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                disabled={chatLoading}
              />
              <button
                onClick={sendQuestion}
                disabled={chatLoading || !question.trim()}
                className="p-2.5 bg-blue-500 hover:bg-blue-600 disabled:opacity-50 text-white rounded-xl transition-colors"
              >
                <Send size={16} />
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
