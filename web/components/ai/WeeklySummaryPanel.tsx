"use client";

import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Sparkles, TrendingUp, RefreshCw } from "lucide-react";
import { api } from "@/lib/api";
import { Button } from "@/components/ui/Button";

interface SummaryData {
  summary: string;
  stats: {
    events_this_week: number;
    tasks_done: number;
    tasks_pending: number;
    tasks_overdue: number;
  };
}

export function WeeklySummaryPanel() {
  const [enabled, setEnabled] = useState(false);

  const { data, isLoading, error, refetch } = useQuery<SummaryData>({
    queryKey: ["weekly-summary"],
    queryFn: () => api.get("/ai/weekly-summary").then((r) => r.data),
    enabled,
    staleTime: 5 * 60 * 1000, // 5 min
  });

  const apiUnavailable =
    (error as { response?: { status?: number } })?.response?.status === 503;

  return (
    <div className="bg-gradient-to-br from-purple-50 to-blue-50 rounded-2xl border border-purple-100 p-5">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 bg-purple-100 rounded-lg flex items-center justify-center">
            <Sparkles size={16} className="text-purple-600" />
          </div>
          <h3 className="font-semibold text-slate-800">Weekly AI Summary</h3>
        </div>
        {data && (
          <button
            onClick={() => refetch()}
            className="p-1.5 rounded-lg hover:bg-white/60 text-slate-500 transition-colors"
            title="Refresh"
          >
            <RefreshCw size={14} />
          </button>
        )}
      </div>

      {!enabled && !data && (
        <div className="text-center py-4">
          <p className="text-sm text-slate-500 mb-3">
            Get an AI-powered summary of your week
          </p>
          <Button size="sm" onClick={() => setEnabled(true)}>
            <TrendingUp size={14} className="mr-2" />
            Generate Summary
          </Button>
        </div>
      )}

      {isLoading && (
        <div className="flex items-center gap-3 py-2">
          <div className="h-5 w-5 animate-spin rounded-full border-2 border-purple-500 border-t-transparent" />
          <p className="text-sm text-slate-500">Analysing your week…</p>
        </div>
      )}

      {apiUnavailable && (
        <p className="text-sm text-amber-600 bg-amber-50 rounded-lg p-3">
          AI features require an Anthropic API key. Set{" "}
          <code className="text-xs">ANTHROPIC_API_KEY</code> in the backend .env file.
        </p>
      )}

      {data && !isLoading && (
        <>
          {/* Stats row */}
          <div className="grid grid-cols-4 gap-2 mb-4">
            {[
              { label: "Events", value: data.stats.events_this_week, color: "text-blue-600" },
              { label: "Done", value: data.stats.tasks_done, color: "text-green-600" },
              { label: "Pending", value: data.stats.tasks_pending, color: "text-amber-600" },
              { label: "Overdue", value: data.stats.tasks_overdue, color: "text-red-600" },
            ].map(({ label, value, color }) => (
              <div key={label} className="bg-white/60 rounded-lg p-2 text-center">
                <p className={`text-lg font-bold ${color}`}>{value}</p>
                <p className="text-xs text-slate-500">{label}</p>
              </div>
            ))}
          </div>

          {/* Summary text */}
          <div className="bg-white/70 rounded-xl p-4">
            <p className="text-sm text-slate-700 whitespace-pre-wrap leading-relaxed">
              {data.summary}
            </p>
          </div>
        </>
      )}
    </div>
  );
}
