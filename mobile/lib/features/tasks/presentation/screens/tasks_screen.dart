import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:crosssync/core/theme/app_theme.dart';
import 'package:crosssync/features/tasks/data/task_repository.dart';
import 'package:crosssync/shared/models/task.dart';

final _taskRepoProvider = Provider((_) => TaskRepository());

final _tasksProvider =
    FutureProvider.autoDispose<List<TaskModel>>((ref) async {
  return ref.watch(_taskRepoProvider).getTasks(parentOnly: true);
});

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tasks'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'To Do'),
              Tab(text: 'In Progress'),
              Tab(text: 'Done'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddTaskDialog(context, ref),
          child: const Icon(Icons.add),
        ),
        body: const TabBarView(
          children: [
            _TaskList(status: TaskStatus.todo),
            _TaskList(status: TaskStatus.inProgress),
            _TaskList(status: TaskStatus.done),
          ],
        ),
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddTaskSheet(ref: ref),
    );
  }
}

class _TaskList extends ConsumerWidget {
  const _TaskList({required this.status});

  final TaskStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(_tasksProvider);

    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (allTasks) {
        final tasks = allTasks.where((t) => t.status == status).toList();
        if (tasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_statusIcon(status), size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Text(
                  'No ${status.label.toLowerCase()} tasks',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: tasks.length,
          itemBuilder: (ctx, i) => _TaskCard(
            task: tasks[i],
            onStatusChanged: (newStatus) async {
              await ref.read(_taskRepoProvider).updateStatus(
                    tasks[i].id,
                    newStatus,
                  );
              ref.invalidate(_tasksProvider);
            },
            onDelete: () async {
              await ref.read(_taskRepoProvider).deleteTask(tasks[i].id);
              ref.invalidate(_tasksProvider);
            },
          ),
        );
      },
    );
  }

  IconData _statusIcon(TaskStatus s) => switch (s) {
        TaskStatus.todo => Icons.radio_button_unchecked,
        TaskStatus.inProgress => Icons.timelapse,
        TaskStatus.done => Icons.check_circle_outline,
      };
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.onStatusChanged,
    required this.onDelete,
  });

  final TaskModel task;
  final ValueChanged<TaskStatus> onStatusChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final priorityColor = switch (task.priority) {
      TaskPriority.high => AppColors.priorityHigh,
      TaskPriority.medium => AppColors.priorityMedium,
      TaskPriority.low => AppColors.priorityLow,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showTaskOptions(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status toggle
              GestureDetector(
                onTap: () => _cycleStatus(),
                child: _StatusIcon(status: task.status),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: task.isCompleted
                            ? Colors.grey
                            : null,
                      ),
                    ),
                    if (task.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        task.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: priorityColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            task.priority.label,
                            style: TextStyle(
                              fontSize: 11,
                              color: priorityColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (task.dueDate != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.calendar_today,
                            size: 12,
                            color: task.isOverdue
                                ? AppColors.error
                                : Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat.MMMd().format(task.dueDate!),
                            style: TextStyle(
                              fontSize: 11,
                              color: task.isOverdue
                                  ? AppColors.error
                                  : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _cycleStatus() {
    final next = switch (task.status) {
      TaskStatus.todo => TaskStatus.inProgress,
      TaskStatus.inProgress => TaskStatus.done,
      TaskStatus.done => TaskStatus.todo,
    };
    onStatusChanged(next);
  }

  void _showTaskOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_circle_outline),
              title: const Text('Move to In Progress'),
              onTap: () {
                Navigator.pop(context);
                onStatusChanged(TaskStatus.inProgress);
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline,
                  color: AppColors.success),
              title: const Text('Mark as Done'),
              onTap: () {
                Navigator.pop(context);
                onStatusChanged(TaskStatus.done);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: AppColors.error),
              title: const Text('Delete',
                  style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      TaskStatus.todo => const Icon(
          Icons.radio_button_unchecked,
          color: AppColors.statusTodo,
        ),
      TaskStatus.inProgress => const Icon(
          Icons.timelapse,
          color: AppColors.statusInProgress,
        ),
      TaskStatus.done => const Icon(
          Icons.check_circle,
          color: AppColors.statusDone,
        ),
    };
  }
}

class _AddTaskSheet extends StatefulWidget {
  const _AddTaskSheet({required this.ref});

  final WidgetRef ref;

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  TaskPriority _priority = TaskPriority.medium;
  DateTime? _dueDate;
  bool _loading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await widget.ref.read(_taskRepoProvider).createTask(
            title: _titleCtrl.text.trim(),
            description: _descCtrl.text.trim().isEmpty
                ? null
                : _descCtrl.text.trim(),
            priority: _priority,
            dueDate: _dueDate,
          );
      widget.ref.invalidate(_tasksProvider);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('New Task',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Task title',
              prefixIcon: Icon(Icons.task_alt),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              prefixIcon: Icon(Icons.notes),
            ),
          ),
          const SizedBox(height: 16),

          // Priority selector
          Row(
            children: [
              const Text('Priority:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(width: 12),
              ...TaskPriority.values.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(p.label),
                    selected: _priority == p,
                    onSelected: (_) => setState(() => _priority = p),
                    selectedColor: switch (p) {
                      TaskPriority.high => AppColors.priorityHigh.withOpacity(0.2),
                      TaskPriority.medium => AppColors.priorityMedium.withOpacity(0.2),
                      TaskPriority.low => AppColors.priorityLow.withOpacity(0.2),
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Due date
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) setState(() => _dueDate = picked);
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    _dueDate == null
                        ? 'Set due date (optional)'
                        : 'Due: ${DateFormat.yMMMd().format(_dueDate!)}',
                    style: TextStyle(
                      color: _dueDate == null ? Colors.grey : null,
                    ),
                  ),
                  if (_dueDate != null) ...[
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _dueDate = null),
                      child: const Icon(Icons.clear, size: 16, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Add Task'),
          ),
        ],
      ),
    );
  }
}
