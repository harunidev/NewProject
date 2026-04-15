"use client";

import { useState } from "react";
import { format } from "date-fns";
import { X } from "lucide-react";
import { calendarApi } from "@/lib/api";
import { Button } from "@/components/ui/Button";

interface Props {
  calendarId: string;
  initialDate: Date;
  onClose: () => void;
  onSuccess: () => void;
}

export function AddEventModal({ calendarId, initialDate, onClose, onSuccess }: Props) {
  const [title, setTitle] = useState("");
  const [location, setLocation] = useState("");
  const [startHour, setStartHour] = useState(10);
  const [endHour, setEndHour] = useState(11);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const hours = Array.from({ length: 24 }, (_, i) => i);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!title.trim()) return;
    if (endHour <= startHour) {
      setError("End time must be after start time");
      return;
    }

    setLoading(true);
    setError(null);
    try {
      const d = format(initialDate, "yyyy-MM-dd");
      await calendarApi.createEvent(calendarId, {
        title: title.trim(),
        start_time: `${d}T${String(startHour).padStart(2, "0")}:00:00Z`,
        end_time: `${d}T${String(endHour).padStart(2, "0")}:00:00Z`,
        location: location.trim() || undefined,
      });
      onSuccess();
    } catch {
      setError("Failed to create event. Please try again.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-2xl shadow-xl w-full max-w-md">
        <div className="flex items-center justify-between p-6 border-b border-slate-100">
          <h2 className="text-lg font-semibold">New Event</h2>
          <button
            onClick={onClose}
            className="p-1 rounded-lg hover:bg-slate-100 transition-colors"
          >
            <X size={18} />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-4">
          {error && (
            <div className="bg-red-50 border border-red-200 text-red-600 text-sm rounded-lg p-3">
              {error}
            </div>
          )}

          <div>
            <label className="block text-sm font-medium text-slate-700 mb-1">
              Title
            </label>
            <input
              autoFocus
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="Event title"
              className="w-full border border-slate-300 rounded-lg px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
              required
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-slate-700 mb-1">
              Date
            </label>
            <div className="border border-slate-200 rounded-lg px-3 py-2.5 text-sm text-slate-500 bg-slate-50">
              {format(initialDate, "EEEE, MMMM d, yyyy")}
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-sm font-medium text-slate-700 mb-1">
                Start time
              </label>
              <select
                value={startHour}
                onChange={(e) => setStartHour(Number(e.target.value))}
                className="w-full border border-slate-300 rounded-lg px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
                {hours.map((h) => (
                  <option key={h} value={h}>
                    {String(h).padStart(2, "0")}:00
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label className="block text-sm font-medium text-slate-700 mb-1">
                End time
              </label>
              <select
                value={endHour}
                onChange={(e) => setEndHour(Number(e.target.value))}
                className="w-full border border-slate-300 rounded-lg px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
                {hours.map((h) => (
                  <option key={h} value={h}>
                    {String(h).padStart(2, "0")}:00
                  </option>
                ))}
              </select>
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-slate-700 mb-1">
              Location (optional)
            </label>
            <input
              value={location}
              onChange={(e) => setLocation(e.target.value)}
              placeholder="Add location"
              className="w-full border border-slate-300 rounded-lg px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>

          <div className="flex gap-3 pt-2">
            <Button variant="secondary" type="button" onClick={onClose} className="flex-1">
              Cancel
            </Button>
            <Button type="submit" loading={loading} className="flex-1">
              Save Event
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
}
