import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:crosssync/core/theme/app_theme.dart';
import 'package:crosssync/features/calendar/data/calendar_repository.dart';
import 'package:crosssync/shared/models/calendar.dart';

final _calRepoProvider = Provider((_) => CalendarRepository());

final _selectedDayProvider = StateProvider<DateTime>((_) => DateTime.now());
final _focusedDayProvider = StateProvider<DateTime>((_) => DateTime.now());

final _eventsProvider = FutureProvider.autoDispose<List<EventModel>>((ref) {
  final focused = ref.watch(_focusedDayProvider);
  final repo = ref.watch(_calRepoProvider);
  final start = DateTime(focused.year, focused.month, 1);
  final end = DateTime(focused.year, focused.month + 1, 0, 23, 59, 59);
  return repo.getEventsInRange(start: start, end: end);
});

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(_selectedDayProvider);
    final focusedDay = ref.watch(_focusedDayProvider);
    final eventsAsync = ref.watch(_eventsProvider);

    // Build event map: date → list of events
    final eventMap = eventsAsync.whenData((events) {
      final Map<DateTime, List<EventModel>> map = {};
      for (final e in events) {
        final key = DateTime(e.startTime.year, e.startTime.month, e.startTime.day);
        map[key] = [...(map[key] ?? []), e];
      }
      return map;
    });

    // Events for selected day
    final selectedEvents = eventMap.whenData((m) {
      final key = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
      return m[key] ?? <EventModel>[];
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Go to today',
            onPressed: () {
              final now = DateTime.now();
              ref.read(_selectedDayProvider.notifier).state = now;
              ref.read(_focusedDayProvider.notifier).state = now;
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEventDialog(context, ref, selectedDay),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Calendar widget
          TableCalendar<EventModel>(
            firstDay: DateTime.utc(2020),
            lastDay: DateTime.utc(2030),
            focusedDay: focusedDay,
            selectedDayPredicate: (day) => isSameDay(day, selectedDay),
            onDaySelected: (selected, focused) {
              ref.read(_selectedDayProvider.notifier).state = selected;
              ref.read(_focusedDayProvider.notifier).state = focused;
            },
            onPageChanged: (focused) {
              ref.read(_focusedDayProvider.notifier).state = focused;
            },
            eventLoader: (day) {
              final key = DateTime(day.year, day.month, day.day);
              return eventMap.valueOrNull?[key] ?? [];
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: AppColors.secondary,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const Divider(height: 1),

          // Events for selected day
          Expanded(
            child: selectedEvents.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (events) => events.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event_available,
                              size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            'No events on ${DateFormat.MMMd().format(selectedDay)}',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: events.length,
                      itemBuilder: (ctx, i) => _EventTile(event: events[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddEventDialog(
      BuildContext context, WidgetRef ref, DateTime day) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddEventSheet(initialDay: day, ref: ref),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});

  final EventModel event;

  @override
  Widget build(BuildContext context) {
    final start = DateFormat.jm().format(event.startTime);
    final end = DateFormat.jm().format(event.endTime);
    final color = event.color ?? AppColors.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 4,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        title: Text(event.title,
            style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text('$start – $end'
            '${event.location != null ? '\n${event.location}' : ''}'),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }
}

class _AddEventSheet extends StatefulWidget {
  const _AddEventSheet({required this.initialDay, required this.ref});

  final DateTime initialDay;
  final WidgetRef ref;

  @override
  State<_AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends State<_AddEventSheet> {
  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  late DateTime _start;
  late DateTime _end;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final base = widget.initialDay;
    _start = DateTime(base.year, base.month, base.day, 10);
    _end = DateTime(base.year, base.month, base.day, 11);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final repo = widget.ref.read(_calRepoProvider);
      final cals = await repo.getCalendars();
      final defaultCal = cals.firstWhere((c) => c.isDefault);
      await repo.createEvent(
        defaultCal.id,
        title: _titleCtrl.text.trim(),
        startTime: _start,
        endTime: _end,
        location: _locationCtrl.text.trim().isEmpty
            ? null
            : _locationCtrl.text.trim(),
      );
      widget.ref.invalidate(_eventsProvider);
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
              const Text('New Event',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Event title',
              prefixIcon: Icon(Icons.title),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _locationCtrl,
            decoration: const InputDecoration(
              labelText: 'Location (optional)',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _TimePicker(
                  label: 'Start',
                  value: _start,
                  onChanged: (t) => setState(() => _start = t),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TimePicker(
                  label: 'End',
                  value: _end,
                  onChanged: (t) => setState(() => _end = t),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Save Event'),
          ),
        ],
      ),
    );
  }
}

class _TimePicker extends StatelessWidget {
  const _TimePicker({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(value),
        );
        if (picked != null) {
          onChanged(DateTime(
              value.year, value.month, value.day,
              picked.hour, picked.minute));
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text(
              DateFormat.jm().format(value),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
