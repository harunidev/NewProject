enum TaskStatus { todo, inProgress, done }

enum TaskPriority { low, medium, high }

extension TaskStatusX on TaskStatus {
  String get value => switch (this) {
        TaskStatus.todo => 'todo',
        TaskStatus.inProgress => 'in_progress',
        TaskStatus.done => 'done',
      };

  String get label => switch (this) {
        TaskStatus.todo => 'To Do',
        TaskStatus.inProgress => 'In Progress',
        TaskStatus.done => 'Done',
      };

  static TaskStatus fromString(String s) => switch (s) {
        'in_progress' => TaskStatus.inProgress,
        'done' => TaskStatus.done,
        _ => TaskStatus.todo,
      };
}

extension TaskPriorityX on TaskPriority {
  String get value => name;
  String get label =>
      '${name[0].toUpperCase()}${name.substring(1)}';

  static TaskPriority fromString(String s) =>
      TaskPriority.values.firstWhere((e) => e.name == s,
          orElse: () => TaskPriority.medium);
}

class TaskModel {
  const TaskModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.status,
    required this.priority,
    required this.isCompleted,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.dueDate,
    this.eventId,
    this.parentTaskId,
  });

  final String id;
  final String userId;
  final String title;
  final String? description;
  final TaskStatus status;
  final TaskPriority priority;
  final bool isCompleted;
  final DateTime? dueDate;
  final String? eventId;
  final String? parentTaskId;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isOverdue =>
      dueDate != null &&
      dueDate!.isBefore(DateTime.now()) &&
      !isCompleted;

  factory TaskModel.fromJson(Map<String, dynamic> json) => TaskModel(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        status: TaskStatusX.fromString(json['status'] as String),
        priority: TaskPriorityX.fromString(json['priority'] as String),
        isCompleted: json['is_completed'] as bool,
        dueDate: json['due_date'] != null
            ? DateTime.parse(json['due_date'] as String).toLocal()
            : null,
        eventId: json['event_id'] as String?,
        parentTaskId: json['parent_task_id'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  TaskModel copyWith({
    TaskStatus? status,
    bool? isCompleted,
    String? title,
    String? description,
    TaskPriority? priority,
    DateTime? dueDate,
  }) =>
      TaskModel(
        id: id,
        userId: userId,
        title: title ?? this.title,
        description: description ?? this.description,
        status: status ?? this.status,
        priority: priority ?? this.priority,
        isCompleted: isCompleted ?? this.isCompleted,
        dueDate: dueDate ?? this.dueDate,
        eventId: eventId,
        parentTaskId: parentTaskId,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
