"use client";

import { useState } from "react";
import {
  DragDropContext,
  Droppable,
  Draggable,
  DropResult,
} from "@hello-pangea/dnd";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { tasksApi } from "@/lib/api";
import { Button } from "@/components/ui/Button";
import { AddTaskModal } from "./AddTaskModal";
import { TaskCard } from "./TaskCard";
import type { Task, TaskStatus } from "@/lib/types";
import { STATUS_LABELS } from "@/lib/types";
import { Plus } from "lucide-react";

const COLUMNS: TaskStatus[] = ["todo", "in_progress", "done"];

const COLUMN_COLORS: Record<TaskStatus, string> = {
  todo: "bg-slate-100",
  in_progress: "bg-blue-50",
  done: "bg-green-50",
};

const COLUMN_HEADER_COLORS: Record<TaskStatus, string> = {
  todo: "text-slate-600",
  in_progress: "text-blue-600",
  done: "text-green-600",
};

export function KanbanBoard() {
  const [showAddModal, setShowAddModal] = useState(false);
  const [addToStatus, setAddToStatus] = useState<TaskStatus>("todo");
  const qc = useQueryClient();

  const { data: tasks = [], isLoading } = useQuery<Task[]>({
    queryKey: ["tasks"],
    queryFn: () =>
      tasksApi.list({ parent_only: true }).then((r) => r.data),
  });

  const updateStatusMutation = useMutation({
    mutationFn: ({ id, status }: { id: string; status: TaskStatus }) =>
      tasksApi.updateStatus(id, status),
    onMutate: async ({ id, status }) => {
      // Optimistic update
      await qc.cancelQueries({ queryKey: ["tasks"] });
      const previous = qc.getQueryData<Task[]>(["tasks"]);
      qc.setQueryData<Task[]>(["tasks"], (old = []) =>
        old.map((t) => (t.id === id ? { ...t, status } : t))
      );
      return { previous };
    },
    onError: (_, __, context) => {
      qc.setQueryData(["tasks"], context?.previous);
    },
    onSettled: () => qc.invalidateQueries({ queryKey: ["tasks"] }),
  });

  const deleteTaskMutation = useMutation({
    mutationFn: (id: string) => tasksApi.delete(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["tasks"] }),
  });

  function onDragEnd(result: DropResult) {
    const { destination, source, draggableId } = result;
    if (!destination) return;
    if (
      destination.droppableId === source.droppableId &&
      destination.index === source.index
    )
      return;

    const newStatus = destination.droppableId as TaskStatus;
    updateStatusMutation.mutate({ id: draggableId, status: newStatus });
  }

  const tasksByStatus = COLUMNS.reduce((acc, status) => {
    acc[status] = tasks.filter((t) => t.status === status);
    return acc;
  }, {} as Record<TaskStatus, Task[]>);

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin h-8 w-8 rounded-full border-4 border-blue-500 border-t-transparent" />
      </div>
    );
  }

  return (
    <div className="h-full flex flex-col">
      <div className="flex items-center justify-between mb-6">
        <h2 className="text-xl font-bold text-slate-800">Tasks</h2>
        <Button
          size="sm"
          onClick={() => {
            setAddToStatus("todo");
            setShowAddModal(true);
          }}
        >
          <Plus size={16} className="mr-1" /> Add Task
        </Button>
      </div>

      <DragDropContext onDragEnd={onDragEnd}>
        <div className="flex gap-4 flex-1 overflow-x-auto pb-4">
          {COLUMNS.map((status) => (
            <div key={status} className="flex-1 min-w-[260px] flex flex-col">
              {/* Column header */}
              <div className="flex items-center justify-between mb-3">
                <div className="flex items-center gap-2">
                  <span
                    className={`text-sm font-semibold ${COLUMN_HEADER_COLORS[status]}`}
                  >
                    {STATUS_LABELS[status]}
                  </span>
                  <span className="bg-white border border-slate-200 text-slate-500 text-xs rounded-full px-2 py-0.5 font-medium">
                    {tasksByStatus[status].length}
                  </span>
                </div>
                <button
                  onClick={() => {
                    setAddToStatus(status);
                    setShowAddModal(true);
                  }}
                  className="p-1 rounded hover:bg-slate-200 transition-colors text-slate-400"
                  title={`Add task to ${STATUS_LABELS[status]}`}
                >
                  <Plus size={14} />
                </button>
              </div>

              {/* Droppable column */}
              <Droppable droppableId={status}>
                {(provided, snapshot) => (
                  <div
                    ref={provided.innerRef}
                    {...provided.droppableProps}
                    className={`flex-1 rounded-xl p-2 transition-colors min-h-[200px] ${
                      COLUMN_COLORS[status]
                    } ${snapshot.isDraggingOver ? "ring-2 ring-blue-300" : ""}`}
                  >
                    {tasksByStatus[status].map((task, index) => (
                      <Draggable
                        key={task.id}
                        draggableId={task.id}
                        index={index}
                      >
                        {(provided, snapshot) => (
                          <div
                            ref={provided.innerRef}
                            {...provided.draggableProps}
                            {...provided.dragHandleProps}
                            className={`mb-2 ${
                              snapshot.isDragging ? "opacity-80 rotate-1" : ""
                            }`}
                          >
                            <TaskCard
                              task={task}
                              onDelete={() =>
                                deleteTaskMutation.mutate(task.id)
                              }
                              onStatusChange={(s) =>
                                updateStatusMutation.mutate({
                                  id: task.id,
                                  status: s,
                                })
                              }
                            />
                          </div>
                        )}
                      </Draggable>
                    ))}
                    {provided.placeholder}

                    {tasksByStatus[status].length === 0 &&
                      !snapshot.isDraggingOver && (
                        <div className="flex items-center justify-center h-24 text-slate-400 text-sm">
                          Drop tasks here
                        </div>
                      )}
                  </div>
                )}
              </Droppable>
            </div>
          ))}
        </div>
      </DragDropContext>

      {showAddModal && (
        <AddTaskModal
          initialStatus={addToStatus}
          onClose={() => setShowAddModal(false)}
          onSuccess={() => {
            qc.invalidateQueries({ queryKey: ["tasks"] });
            setShowAddModal(false);
          }}
        />
      )}
    </div>
  );
}
