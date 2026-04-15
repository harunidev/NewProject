"use client";

import { format, parseISO } from "date-fns";
import { Calendar, Trash2, MoreVertical } from "lucide-react";
import { useState, useRef, useEffect } from "react";
import type { Task, TaskStatus } from "@/lib/types";
import { PRIORITY_COLORS, STATUS_LABELS } from "@/lib/types";
import { cn, isOverdue } from "@/lib/utils";

interface Props {
  task: Task;
  onDelete: () => void;
  onStatusChange: (status: TaskStatus) => void;
}

export function TaskCard({ task, onDelete, onStatusChange }: Props) {
  const [menuOpen, setMenuOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) {
        setMenuOpen(false);
      }
    }
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  const overdue = isOverdue(task.due_date, task.is_completed);

  return (
    <div className="bg-white rounded-lg border border-slate-200 p-3 shadow-sm hover:shadow-md transition-shadow">
      <div className="flex items-start justify-between gap-2">
        <p
          className={cn(
            "text-sm font-medium text-slate-800 flex-1 leading-snug",
            task.is_completed && "line-through text-slate-400"
          )}
        >
          {task.title}
        </p>

        {/* Context menu */}
        <div className="relative flex-shrink-0" ref={menuRef}>
          <button
            onClick={() => setMenuOpen((v) => !v)}
            className="p-0.5 rounded hover:bg-slate-100 text-slate-400 transition-colors"
          >
            <MoreVertical size={14} />
          </button>

          {menuOpen && (
            <div className="absolute right-0 top-6 bg-white border border-slate-200 rounded-lg shadow-lg z-10 w-40 py-1">
              {(["todo", "in_progress", "done"] as TaskStatus[]).map((s) => (
                <button
                  key={s}
                  onClick={() => {
                    onStatusChange(s);
                    setMenuOpen(false);
                  }}
                  disabled={task.status === s}
                  className="w-full text-left px-3 py-1.5 text-xs hover:bg-slate-50 disabled:text-slate-300 transition-colors"
                >
                  Move to {STATUS_LABELS[s]}
                </button>
              ))}
              <hr className="my-1 border-slate-100" />
              <button
                onClick={() => {
                  onDelete();
                  setMenuOpen(false);
                }}
                className="w-full text-left px-3 py-1.5 text-xs text-red-500 hover:bg-red-50 transition-colors flex items-center gap-1.5"
              >
                <Trash2 size={11} /> Delete
              </button>
            </div>
          )}
        </div>
      </div>

      {task.description && (
        <p className="text-xs text-slate-500 mt-1.5 line-clamp-2">
          {task.description}
        </p>
      )}

      <div className="flex items-center gap-2 mt-2.5 flex-wrap">
        <span
          className={cn(
            "text-xs px-2 py-0.5 rounded-full font-medium",
            PRIORITY_COLORS[task.priority]
          )}
        >
          {task.priority}
        </span>

        {task.due_date && (
          <span
            className={cn(
              "text-xs flex items-center gap-1",
              overdue ? "text-red-500 font-medium" : "text-slate-400"
            )}
          >
            <Calendar size={10} />
            {format(parseISO(task.due_date), "MMM d")}
            {overdue && " · Overdue"}
          </span>
        )}
      </div>
    </div>
  );
}
