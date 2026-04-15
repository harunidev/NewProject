import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crosssync/features/ai/data/ai_repository.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _aiRepoProvider = Provider((_) => AiRepository());

final weeklySummaryProvider =
    FutureProvider.autoDispose<WeeklySummaryResult>((ref) async {
  return ref.watch(_aiRepoProvider).getWeeklySummary();
});

// ---------------------------------------------------------------------------
// AI Features Screen
// ---------------------------------------------------------------------------

class AiScreen extends ConsumerWidget {
  const AiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Features'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(weeklySummaryProvider),
          ),
        ],
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _WeeklySummaryCard(),
            SizedBox(height: 20),
            _CalendarSuggestCard(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Weekly Summary Card
// ---------------------------------------------------------------------------

class _WeeklySummaryCard extends StatefulWidget {
  const _WeeklySummaryCard();

  @override
  State<_WeeklySummaryCard> createState() => _WeeklySummaryCardState();
}

class _WeeklySummaryCardState extends State<_WeeklySummaryCard> {
  bool _enabled = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.deepPurple.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.auto_awesome,
                      color: Colors.deepPurple, size: 18),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Weekly AI Summary',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!_enabled)
              Center(
                child: Column(
                  children: [
                    const Text(
                      'Get an AI-powered summary of your week',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => setState(() => _enabled = true),
                      icon: const Icon(Icons.trending_up, size: 16),
                      label: const Text('Generate Summary'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                      ),
                    ),
                  ],
                ),
              )
            else
              const _SummaryContent(),
          ],
        ),
      ),
    );
  }
}

class _SummaryContent extends ConsumerWidget {
  const _SummaryContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(weeklySummaryProvider);

    return async.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) {
        final isApiError =
            e.toString().contains('503') || e.toString().contains('API key');
        if (isApiError) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: const Text(
              'AI features require an Anthropic API key. Set ANTHROPIC_API_KEY in the backend .env file.',
              style: TextStyle(fontSize: 13),
            ),
          );
        }
        return Text('Error: $e', style: const TextStyle(color: Colors.red));
      },
      data: (result) => Column(
        children: [
          // Stats grid
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.1,
            children: [
              _StatChip(
                  label: 'Events',
                  value: result.stats.eventsThisWeek,
                  color: Colors.blue),
              _StatChip(
                  label: 'Done',
                  value: result.stats.tasksDone,
                  color: Colors.green),
              _StatChip(
                  label: 'Pending',
                  value: result.stats.tasksPending,
                  color: Colors.amber.shade700),
              _StatChip(
                  label: 'Overdue',
                  value: result.stats.tasksOverdue,
                  color: Colors.red),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white70,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              result.summary,
              style: const TextStyle(height: 1.5, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$value',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Calendar Slot Suggestion Card
// ---------------------------------------------------------------------------

class _CalendarSuggestCard extends ConsumerStatefulWidget {
  const _CalendarSuggestCard();

  @override
  ConsumerState<_CalendarSuggestCard> createState() =>
      _CalendarSuggestCardState();
}

class _CalendarSuggestCardState extends ConsumerState<_CalendarSuggestCard> {
  final _taskController = TextEditingController();
  int _duration = 60;
  bool _loading = false;
  String? _error;
  List<CalendarSlotSuggestion> _suggestions = [];

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  Future<void> _suggest() async {
    final title = _taskController.text.trim();
    if (title.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _suggestions = [];
    });
    try {
      final result = await ref.read(_aiRepoProvider).suggestCalendarSlots(
            taskTitle: title,
            durationMinutes: _duration,
          );
      setState(() => _suggestions = result);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.calendar_today,
                      color: Colors.blue.shade700, size: 18),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Smart Scheduling',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'AI suggests the best times for your tasks',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _taskController,
              decoration: InputDecoration(
                labelText: 'Task title',
                hintText: 'e.g. Team meeting',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Duration:'),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: _duration.toDouble(),
                    min: 15,
                    max: 240,
                    divisions: 9,
                    label: '${_duration}min',
                    onChanged: (v) => setState(() => _duration = v.round()),
                  ),
                ),
                Text('${_duration}m',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _suggest,
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.auto_awesome, size: 16),
                label: const Text('Suggest Time Slots'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
            if (_suggestions.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Suggested Time Slots',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ..._suggestions.map(
                (s) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_formatTime(s.startTime)} – ${_formatTime(s.endTime)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.reason,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return iso;
    }
  }
}
