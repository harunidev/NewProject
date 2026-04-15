import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatTime(isoString: string) {
  return new Date(isoString).toLocaleTimeString([], {
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function formatDate(isoString: string) {
  return new Date(isoString).toLocaleDateString([], {
    month: "short",
    day: "numeric",
  });
}

export function isOverdue(dueDate: string | null, isCompleted: boolean) {
  if (!dueDate || isCompleted) return false;
  return new Date(dueDate) < new Date();
}
