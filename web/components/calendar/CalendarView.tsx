"use client";

import { useState, useMemo } from "react";
import {
  format,
  startOfMonth,
  endOfMonth,
  startOfWeek,
  endOfWeek,
  addDays,
  isSameMonth,
  isSameDay,
  addMonths,
  subMonths,
  parseISO,
} from "date-fns";
import { ChevronLeft, ChevronRight, Plus } from "lucide-react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { calendarApi } from "@/lib/api";
import { Button } from "@/components/ui/Button";
import { AddEventModal } from "./AddEventModal";
import type { CalendarEvent, Calendar } from "@/lib/types";

export function CalendarView() {
  const [currentMonth, setCurrentMonth] = useState(new Date());
  const [selectedDay, setSelectedDay] = useState(new Date());
  const [showAddModal, setShowAddModal] = useState(false);
  const qc = useQueryClient();

  // Fetch calendars
  const { data: calendars = [] } = useQuery<Calendar[]>({
    queryKey: ["calendars"],
    queryFn: () => calendarApi.list().then((r) => r.data),
  });

  // Fetch events for visible month (+ surrounding week buffer)
  const rangeStart = format(
    startOfWeek(startOfMonth(currentMonth)),
    "yyyy-MM-dd'T'HH:mm:ss'Z'"
  );
  const rangeEnd = format(
    endOfWeek(endOfMonth(currentMonth)),
    "yyyy-MM-dd'T'23:59:59'Z'"
  );

  const { data: events = [] } = useQuery<CalendarEvent[]>({
    queryKey: ["events", rangeStart, rangeEnd],
    queryFn: () =>
      calendarApi.getEventsInRange(rangeStart, rangeEnd).then((r) => r.data),
  });

  // Build event map: dateKey → events[]
  const eventMap = useMemo(() => {
    const map = new Map<string, CalendarEvent[]>();
    for (const ev of events) {
      const key = format(parseISO(ev.start_time), "yyyy-MM-dd");
      map.set(key, [...(map.get(key) ?? []), ev]);
    }
    return map;
  }, [events]);

  // Build calendar grid
  const weeks = useMemo(() => {
    const start = startOfWeek(startOfMonth(currentMonth));
    const end = endOfWeek(endOfMonth(currentMonth));
    const days: Date[] = [];
    let current = start;
    while (current <= end) {
      days.push(current);
      current = addDays(current, 1);
    }
    const result: Date[][] = [];
    for (let i = 0; i < days.length; i += 7) {
      result.push(days.slice(i, i + 7));
    }
    return result;
  }, [currentMonth]);

  const selectedDateEvents = useMemo(() => {
    const key = format(selectedDay, "yyyy-MM-dd");
    return eventMap.get(key) ?? [];
  }, [selectedDay, eventMap]);

  const defaultCalendar = calendars.find((c) => c.is_default) ?? calendars[0];

  return (
    <div className="flex flex-col h-full">
      {/* Header */}
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-xl font-bold text-slate-800">
          {format(currentMonth, "MMMM yyyy")}
        </h2>
        <div className="flex items-center gap-2">
          <Button
            variant="secondary"
            size="sm"
            onClick={() => {
              setCurrentMonth(new Date());
              setSelectedDay(new Date());
            }}
          >
            Today
          </Button>
          <button
            onClick={() => setCurrentMonth(subMonths(currentMonth, 1))}
            className="p-1.5 rounded-lg hover:bg-slate-100 transition-colors"
          >
            <ChevronLeft size={18} />
          </button>
          <button
            onClick={() => setCurrentMonth(addMonths(currentMonth, 1))}
            className="p-1.5 rounded-lg hover:bg-slate-100 transition-colors"
          >
            <ChevronRight size={18} />
          </button>
          <Button size="sm" onClick={() => setShowAddModal(true)}>
            <Plus size={16} className="mr-1" /> Add Event
          </Button>
        </div>
      </div>

      {/* Day headers */}
      <div className="grid grid-cols-7 mb-1">
        {["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"].map((d) => (
          <div
            key={d}
            className="text-center text-xs font-semibold text-slate-400 py-2"
          >
            {d}
          </div>
        ))}
      </div>

      {/* Calendar grid */}
      <div className="flex-1 grid grid-rows-6 border-l border-t border-slate-200 rounded-lg overflow-hidden">
        {weeks.map((week, wi) => (
          <div key={wi} className="grid grid-cols-7">
            {week.map((day, di) => {
              const key = format(day, "yyyy-MM-dd");
              const dayEvents = eventMap.get(key) ?? [];
              const isToday = isSameDay(day, new Date());
              const isSelected = isSameDay(day, selectedDay);
              const isCurrentMonth = isSameMonth(day, currentMonth);

              return (
                <div
                  key={di}
                  onClick={() => setSelectedDay(day)}
                  className={`min-h-[80px] border-r border-b border-slate-200 p-1.5 cursor-pointer transition-colors ${
                    isCurrentMonth ? "bg-white" : "bg-slate-50"
                  } ${isSelected ? "ring-2 ring-inset ring-blue-400" : ""} hover:bg-blue-50`}
                >
                  <div className="flex justify-end">
                    <span
                      className={`text-sm w-7 h-7 flex items-center justify-center rounded-full font-medium ${
                        isToday
                          ? "bg-blue-500 text-white"
                          : isCurrentMonth
                          ? "text-slate-700"
                          : "text-slate-300"
                      }`}
                    >
                      {format(day, "d")}
                    </span>
                  </div>
                  <div className="mt-1 space-y-0.5">
                    {dayEvents.slice(0, 2).map((ev) => (
                      <div
                        key={ev.id}
                        className="text-xs truncate rounded px-1 py-0.5 font-medium"
                        style={{
                          backgroundColor: `${ev.color ?? "#3B82F6"}20`,
                          color: ev.color ?? "#3B82F6",
                        }}
                      >
                        {ev.title}
                      </div>
                    ))}
                    {dayEvents.length > 2 && (
                      <div className="text-xs text-slate-400 px-1">
                        +{dayEvents.length - 2} more
                      </div>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        ))}
      </div>

      {/* Selected day events panel */}
      <div className="mt-4 border-t border-slate-200 pt-4">
        <h3 className="text-sm font-semibold text-slate-600 mb-2">
          {format(selectedDay, "EEEE, MMMM d")}
        </h3>
        {selectedDateEvents.length === 0 ? (
          <p className="text-sm text-slate-400">No events</p>
        ) : (
          <div className="space-y-2">
            {selectedDateEvents.map((ev) => (
              <div
                key={ev.id}
                className="flex items-start gap-3 p-3 bg-white rounded-lg border border-slate-200"
              >
                <div
                  className="w-1 self-stretch rounded-full flex-shrink-0"
                  style={{ backgroundColor: ev.color ?? "#3B82F6" }}
                />
                <div className="flex-1 min-w-0">
                  <p className="font-medium text-slate-800 text-sm">
                    {ev.title}
                  </p>
                  <p className="text-xs text-slate-500 mt-0.5">
                    {format(parseISO(ev.start_time), "h:mm a")} –{" "}
                    {format(parseISO(ev.end_time), "h:mm a")}
                    {ev.location ? ` · ${ev.location}` : ""}
                  </p>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {showAddModal && defaultCalendar && (
        <AddEventModal
          calendarId={defaultCalendar.id}
          initialDate={selectedDay}
          onClose={() => setShowAddModal(false)}
          onSuccess={() => {
            qc.invalidateQueries({ queryKey: ["events"] });
            setShowAddModal(false);
          }}
        />
      )}
    </div>
  );
}
