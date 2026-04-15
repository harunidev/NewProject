export interface User {
  id: string;
  email: string;
  name: string;
  avatar_url: string | null;
  is_active: boolean;
}

export interface Calendar {
  id: string;
  user_id: string;
  name: string;
  color: string;
  is_default: boolean;
  created_at: string;
}

export interface CalendarEvent {
  id: string;
  calendar_id: string;
  title: string;
  description: string | null;
  start_time: string;
  end_time: string;
  recurrence_rule: string | null;
  location: string | null;
  color: string | null;
  is_all_day: boolean;
  created_at: string;
  updated_at: string;
}

export type TaskStatus = "todo" | "in_progress" | "done";
export type TaskPriority = "low" | "medium" | "high";

export interface Task {
  id: string;
  user_id: string;
  title: string;
  description: string | null;
  status: TaskStatus;
  priority: TaskPriority;
  due_date: string | null;
  is_completed: boolean;
  event_id: string | null;
  parent_task_id: string | null;
  created_at: string;
  updated_at: string;
}

export const PRIORITY_COLORS: Record<TaskPriority, string> = {
  low: "text-slate-500 bg-slate-100",
  medium: "text-amber-600 bg-amber-100",
  high: "text-red-600 bg-red-100",
};

export const STATUS_LABELS: Record<TaskStatus, string> = {
  todo: "To Do",
  in_progress: "In Progress",
  done: "Done",
};
