import 'package:dio/dio.dart';
import 'package:crosssync/core/api/api_client.dart';
import 'package:crosssync/shared/models/calendar.dart';

class CalendarRepository {
  CalendarRepository() : _dio = ApiClient.instance.dio;

  final Dio _dio;

  // ── Calendars ──────────────────────────────────────────────────────────────

  Future<List<CalendarModel>> getCalendars() async {
    final res = await _dio.get('/calendar/');
    return (res.data as List)
        .map((e) => CalendarModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CalendarModel> createCalendar({
    required String name,
    required String colorHex,
    bool isDefault = false,
  }) async {
    final res = await _dio.post('/calendar/', data: {
      'name': name,
      'color': colorHex,
      'is_default': isDefault,
    });
    return CalendarModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<CalendarModel> updateCalendar(
    String calendarId, {
    String? name,
    String? colorHex,
  }) async {
    final res = await _dio.patch('/calendar/$calendarId', data: {
      if (name != null) 'name': name,
      if (colorHex != null) 'color': colorHex,
    });
    return CalendarModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteCalendar(String calendarId) =>
      _dio.delete('/calendar/$calendarId');

  // ── Events ─────────────────────────────────────────────────────────────────

  Future<List<EventModel>> getEventsInRange({
    required DateTime start,
    required DateTime end,
    String? calendarId,
  }) async {
    final res = await _dio.get('/calendar/events/range', queryParameters: {
      'start': start.toUtc().toIso8601String(),
      'end': end.toUtc().toIso8601String(),
      if (calendarId != null) 'calendar_id': calendarId,
    });
    return (res.data as List)
        .map((e) => EventModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<EventModel> createEvent(
    String calendarId, {
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    String? description,
    String? location,
    String? colorHex,
    bool isAllDay = false,
    String? recurrenceRule,
  }) async {
    final res = await _dio.post('/calendar/$calendarId/events', data: {
      'title': title,
      'start_time': startTime.toUtc().toIso8601String(),
      'end_time': endTime.toUtc().toIso8601String(),
      if (description != null) 'description': description,
      if (location != null) 'location': location,
      if (colorHex != null) 'color': colorHex,
      'is_all_day': isAllDay,
      if (recurrenceRule != null) 'recurrence_rule': recurrenceRule,
    });
    return EventModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<EventModel> updateEvent(
    String calendarId,
    String eventId, {
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    String? description,
    String? location,
  }) async {
    final res = await _dio.patch(
      '/calendar/$calendarId/events/$eventId',
      data: {
        if (title != null) 'title': title,
        if (startTime != null)
          'start_time': startTime.toUtc().toIso8601String(),
        if (endTime != null) 'end_time': endTime.toUtc().toIso8601String(),
        if (description != null) 'description': description,
        if (location != null) 'location': location,
      },
    );
    return EventModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteEvent(String calendarId, String eventId) =>
      _dio.delete('/calendar/$calendarId/events/$eventId');
}
