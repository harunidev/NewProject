import 'package:flutter/material.dart';

class CalendarModel {
  const CalendarModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.colorHex,
    required this.isDefault,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String name;
  final String colorHex;
  final bool isDefault;
  final DateTime createdAt;

  Color get color {
    final hex = colorHex.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  factory CalendarModel.fromJson(Map<String, dynamic> json) => CalendarModel(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        name: json['name'] as String,
        colorHex: json['color'] as String,
        isDefault: json['is_default'] as bool,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class EventModel {
  const EventModel({
    required this.id,
    required this.calendarId,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.description,
    this.location,
    this.colorHex,
    this.isAllDay = false,
    this.recurrenceRule,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String calendarId;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String? description;
  final String? location;
  final String? colorHex;
  final bool isAllDay;
  final String? recurrenceRule;
  final DateTime createdAt;
  final DateTime updatedAt;

  Color? get color {
    if (colorHex == null) return null;
    final hex = colorHex!.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  factory EventModel.fromJson(Map<String, dynamic> json) => EventModel(
        id: json['id'] as String,
        calendarId: json['calendar_id'] as String,
        title: json['title'] as String,
        startTime: DateTime.parse(json['start_time'] as String).toLocal(),
        endTime: DateTime.parse(json['end_time'] as String).toLocal(),
        description: json['description'] as String?,
        location: json['location'] as String?,
        colorHex: json['color'] as String?,
        isAllDay: json['is_all_day'] as bool? ?? false,
        recurrenceRule: json['recurrence_rule'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}
