import 'package:dio/dio.dart';
import 'package:crosssync/core/api/api_client.dart';

class WeeklySummaryStats {
  final int eventsThisWeek;
  final int tasksDone;
  final int tasksPending;
  final int tasksOverdue;

  const WeeklySummaryStats({
    required this.eventsThisWeek,
    required this.tasksDone,
    required this.tasksPending,
    required this.tasksOverdue,
  });

  factory WeeklySummaryStats.fromJson(Map<String, dynamic> json) =>
      WeeklySummaryStats(
        eventsThisWeek: json['events_this_week'] as int,
        tasksDone: json['tasks_done'] as int,
        tasksPending: json['tasks_pending'] as int,
        tasksOverdue: json['tasks_overdue'] as int,
      );
}

class WeeklySummaryResult {
  final String summary;
  final WeeklySummaryStats stats;

  const WeeklySummaryResult({required this.summary, required this.stats});

  factory WeeklySummaryResult.fromJson(Map<String, dynamic> json) =>
      WeeklySummaryResult(
        summary: json['summary'] as String,
        stats: WeeklySummaryStats.fromJson(
            json['stats'] as Map<String, dynamic>),
      );
}

class CalendarSlotSuggestion {
  final String startTime;
  final String endTime;
  final String reason;

  const CalendarSlotSuggestion({
    required this.startTime,
    required this.endTime,
    required this.reason,
  });

  factory CalendarSlotSuggestion.fromJson(Map<String, dynamic> json) =>
      CalendarSlotSuggestion(
        startTime: json['start_time'] as String,
        endTime: json['end_time'] as String,
        reason: json['reason'] as String,
      );
}

class AiRepository {
  final Dio _dio = ApiClient.instance.dio;

  Future<WeeklySummaryResult> getWeeklySummary() async {
    final res = await _dio.get('/ai/weekly-summary');
    return WeeklySummaryResult.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<CalendarSlotSuggestion>> suggestCalendarSlots({
    required String taskTitle,
    required int durationMinutes,
  }) async {
    final res = await _dio.post('/ai/calendar/suggest', data: {
      'task_title': taskTitle,
      'duration_minutes': durationMinutes,
    });
    return (res.data['suggestions'] as List)
        .map((e) =>
            CalendarSlotSuggestion.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
