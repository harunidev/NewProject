import 'package:dio/dio.dart';
import 'package:crosssync/core/api/api_client.dart';
import 'package:crosssync/shared/models/task.dart';

class TaskRepository {
  TaskRepository() : _dio = ApiClient.instance.dio;

  final Dio _dio;

  Future<List<TaskModel>> getTasks({
    TaskStatus? status,
    TaskPriority? priority,
    bool parentOnly = true,
  }) async {
    final res = await _dio.get('/tasks/', queryParameters: {
      if (status != null) 'status': status.value,
      if (priority != null) 'priority': priority.value,
      if (parentOnly) 'parent_only': true,
    });
    return (res.data as List)
        .map((e) => TaskModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<TaskModel> createTask({
    required String title,
    String? description,
    TaskStatus status = TaskStatus.todo,
    TaskPriority priority = TaskPriority.medium,
    DateTime? dueDate,
    String? eventId,
    String? parentTaskId,
  }) async {
    final res = await _dio.post('/tasks/', data: {
      'title': title,
      if (description != null) 'description': description,
      'status': status.value,
      'priority': priority.value,
      if (dueDate != null) 'due_date': dueDate.toUtc().toIso8601String(),
      if (eventId != null) 'event_id': eventId,
      if (parentTaskId != null) 'parent_task_id': parentTaskId,
    });
    return TaskModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<TaskModel> updateStatus(String taskId, TaskStatus status) async {
    final res = await _dio.patch('/tasks/$taskId/status', data: {
      'status': status.value,
    });
    return TaskModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<TaskModel> updateTask(
    String taskId, {
    String? title,
    String? description,
    TaskPriority? priority,
    DateTime? dueDate,
  }) async {
    final res = await _dio.patch('/tasks/$taskId', data: {
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (priority != null) 'priority': priority.value,
      if (dueDate != null) 'due_date': dueDate.toUtc().toIso8601String(),
    });
    return TaskModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteTask(String taskId) => _dio.delete('/tasks/$taskId');
}
