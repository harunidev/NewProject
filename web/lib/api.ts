import axios, { AxiosError, InternalAxiosRequestConfig } from "axios";

const BASE_URL =
  process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8001/api/v1";

const ACCESS_KEY = "cs_access";
const REFRESH_KEY = "cs_refresh";

export const api = axios.create({
  baseURL: BASE_URL,
  headers: { "Content-Type": "application/json" },
  timeout: 15_000,
});

// ── Token helpers ─────────────────────────────────────────────────────────────
export const tokenStorage = {
  getAccess: () =>
    typeof window !== "undefined" ? localStorage.getItem(ACCESS_KEY) : null,
  getRefresh: () =>
    typeof window !== "undefined" ? localStorage.getItem(REFRESH_KEY) : null,
  save: (access: string, refresh: string) => {
    localStorage.setItem(ACCESS_KEY, access);
    localStorage.setItem(REFRESH_KEY, refresh);
  },
  clear: () => {
    localStorage.removeItem(ACCESS_KEY);
    localStorage.removeItem(REFRESH_KEY);
  },
};

// ── Request interceptor — attach Bearer token ─────────────────────────────────
api.interceptors.request.use((config: InternalAxiosRequestConfig) => {
  const token = tokenStorage.getAccess();
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

// ── Response interceptor — auto-refresh on 401 ───────────────────────────────
let refreshing = false;

api.interceptors.response.use(
  (res) => res,
  async (err: AxiosError) => {
    const original = err.config as InternalAxiosRequestConfig & {
      _retry?: boolean;
    };

    if (err.response?.status === 401 && !original._retry && !refreshing) {
      original._retry = true;
      refreshing = true;

      try {
        const refresh = tokenStorage.getRefresh();
        if (!refresh) throw new Error("No refresh token");

        const { data } = await axios.post(`${BASE_URL}/auth/refresh`, {
          refresh_token: refresh,
        });

        tokenStorage.save(data.access_token, data.refresh_token);
        original.headers.Authorization = `Bearer ${data.access_token}`;
        return api(original);
      } catch {
        tokenStorage.clear();
        window.location.href = "/login";
      } finally {
        refreshing = false;
      }
    }

    return Promise.reject(err);
  }
);

// ── API functions ─────────────────────────────────────────────────────────────

// Auth
export const authApi = {
  register: (email: string, password: string, name: string) =>
    api.post("/auth/register", { email, password, name }),
  login: (email: string, password: string) =>
    api.post("/auth/login", { email, password }),
  me: () => api.get("/auth/me"),
};

// Calendar
export const calendarApi = {
  list: () => api.get("/calendar/"),
  create: (name: string, color: string) =>
    api.post("/calendar/", { name, color }),
  update: (id: string, data: { name?: string; color?: string }) =>
    api.patch(`/calendar/${id}`, data),
  delete: (id: string) => api.delete(`/calendar/${id}`),

  getEventsInRange: (start: string, end: string, calendarId?: string) =>
    api.get("/calendar/events/range", {
      params: { start, end, ...(calendarId ? { calendar_id: calendarId } : {}) },
    }),
  createEvent: (
    calendarId: string,
    data: {
      title: string;
      start_time: string;
      end_time: string;
      description?: string;
      location?: string;
      color?: string;
      is_all_day?: boolean;
    }
  ) => api.post(`/calendar/${calendarId}/events`, data),
  updateEvent: (
    calendarId: string,
    eventId: string,
    data: Partial<{
      title: string;
      start_time: string;
      end_time: string;
      description: string;
      location: string;
    }>
  ) => api.patch(`/calendar/${calendarId}/events/${eventId}`, data),
  deleteEvent: (calendarId: string, eventId: string) =>
    api.delete(`/calendar/${calendarId}/events/${eventId}`),
};

// Tasks
export const tasksApi = {
  list: (params?: { status?: string; priority?: string; parent_only?: boolean }) =>
    api.get("/tasks/", { params }),
  create: (data: {
    title: string;
    description?: string;
    status?: string;
    priority?: string;
    due_date?: string;
    event_id?: string;
    parent_task_id?: string;
  }) => api.post("/tasks/", data),
  updateStatus: (id: string, status: string) =>
    api.patch(`/tasks/${id}/status`, { status }),
  update: (id: string, data: Partial<{
    title: string;
    description: string;
    priority: string;
    due_date: string;
  }>) => api.patch(`/tasks/${id}`, data),
  delete: (id: string) => api.delete(`/tasks/${id}`),
  subtasks: (id: string) => api.get(`/tasks/${id}/subtasks`),
};
