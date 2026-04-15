"use client";

import { CalendarView } from "@/components/calendar/CalendarView";
import { WeeklySummaryPanel } from "@/components/ai/WeeklySummaryPanel";

export default function CalendarPage() {
  return (
    <div className="flex flex-col gap-6 h-full">
      <CalendarView />
      <WeeklySummaryPanel />
    </div>
  );
}
