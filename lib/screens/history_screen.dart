// lib/screens/history_screen.dart

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../database/database.dart';
import '../providers/database_provider.dart';
import '../providers/project_list_provider.dart';
import '../providers/week_entries_provider.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(weekEntriesProvider);
    final projectsAsync = ref.watch(projectListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
      ),
      body: entriesAsync.when(
        data: (entries) => projectsAsync.when(
          data: (projects) => _HistoryBody(entries: entries, projects: projects),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _HistoryBody extends ConsumerStatefulWidget {
  const _HistoryBody({required this.entries, required this.projects});

  final List<TimeEntry> entries;
  final List<Project> projects;

  @override
  ConsumerState<_HistoryBody> createState() => _HistoryBodyState();
}

class _HistoryBodyState extends ConsumerState<_HistoryBody> {
  // --- Helpers ---

  Duration _entryDuration(TimeEntry e) {
    if (e.endTime == null) return Duration.zero;
    return Duration(milliseconds: e.endTime! - e.startTime);
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  String _formatTime(int ms) =>
      DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(ms));

  Color _projectColor(int projectId) {
    final p = widget.projects.firstWhere(
      (p) => p.id == projectId,
      orElse: () => Project(id: -1, name: '', color: '9E9E9E', hourlyRate: null),
    );
    final hex = p.color.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  String _projectName(int projectId) {
    return widget.projects
        .firstWhere(
          (p) => p.id == projectId,
          orElse: () => Project(id: -1, name: 'Unknown', color: '9E9E9E', hourlyRate: null),
        )
        .name;
  }

  // Groups entries by calendar day (as DateTime midnight local)
  Map<DateTime, List<TimeEntry>> _groupByDay(List<TimeEntry> entries) {
    final map = <DateTime, List<TimeEntry>>{};
    for (final e in entries) {
      final dt = DateTime.fromMillisecondsSinceEpoch(e.startTime);
      final day = DateTime(dt.year, dt.month, dt.day);
      map.putIfAbsent(day, () => []).add(e);
    }
    return map;
  }

  // "Today, May 14"  |  "Yesterday, May 13"  |  "Monday, May 12"
  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (day == today) return 'Today, ${DateFormat('MMM d').format(day)}';
    if (day == yesterday) return 'Yesterday, ${DateFormat('MMM d').format(day)}';
    return DateFormat('EEEE, MMM d').format(day);
  }

  // Total completed duration across all entries
  Duration _totalDuration(List<TimeEntry> entries) =>
      entries.fold(Duration.zero, (acc, e) => acc + _entryDuration(e));

  // --- Pull-to-refresh ---
  Future<void> _onRefresh() async {
    ref.invalidate(weekEntriesProvider);
    // Give the stream a moment to emit the fresh snapshot
    await Future.delayed(const Duration(milliseconds: 400));
  }

  // --- Edit / Delete bottom sheet ---
  void _showEntryOptions(BuildContext context, TimeEntry entry) {
    final noteController = TextEditingController(text: entry.note ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _projectName(entry.projectId),
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              '${_formatTime(entry.startTime)} – ${entry.endTime != null ? _formatTime(entry.endTime!) : 'ongoing'}  ·  ${_formatDuration(_entryDuration(entry))}',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Note',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                final db = ref.read(databaseProvider);
                await (db.update(db.timeEntries)
                      ..where((t) => t.id.equals(entry.id)))
                    .write(TimeEntriesCompanion(
                  note: drift.Value(noteController.text.isEmpty ? null : noteController.text),
                ));
                ref.invalidate(weekEntriesProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save Note'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: ctx,
                  builder: (dCtx) => AlertDialog(
                    title: const Text('Delete entry?'),
                    content: const Text('This cannot be undone.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dCtx, false),
                          child: const Text('Cancel')),
                      TextButton(
                          onPressed: () => Navigator.pop(dCtx, true),
                          child: const Text('Delete', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirm == true) {
                  final db = ref.read(databaseProvider);
                  await (db.delete(db.timeEntries)
                        ..where((t) => t.id.equals(entry.id)))
                      .go();
                  ref.invalidate(weekEntriesProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Delete Entry'),
            ),
          ],
        ),
      ),
    );
  }

  // --- Build ---
  @override
  Widget build(BuildContext context) {
    final grouped = _groupByDay(widget.entries);
    final sortedDays = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final total = _totalDuration(widget.entries);

    // Build a flat list of items: [header, entry, entry, header, entry, ...]
    final items = <_ListItem>[];
    for (final day in sortedDays) {
      items.add(_ListItem.header(day));
      for (final e in grouped[day]!) {
        items.add(_ListItem.entry(e));
      }
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── Week summary banner ──
          SliverToBoxAdapter(
            child: _WeekSummaryBanner(
              totalDuration: total,
              entryCount: widget.entries.length,
            ),
          ),

          // ── Empty state ──
          if (widget.entries.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Text('No entries this week.')),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = items[index];
                  if (item.isHeader) {
                    return _DayHeader(label: _dayLabel(item.day!));
                  }
                  final entry = item.entry!;
                  return _EntryCard(
                    projectName: _projectName(entry.projectId),
                    projectColor: _projectColor(entry.projectId),
                    startMs: entry.startTime,
                    endMs: entry.endTime,
                    duration: _entryDuration(entry),
                    note: entry.note,
                    formatTime: _formatTime,
                    formatDuration: _formatDuration,
                    onTap: () => _showEntryOptions(context, entry),
                  );
                },
                childCount: items.length,
              ),
            ),
        ],
      ),
    );
  }
}

// ── List item discriminated union ──────────────────────────────────────────

class _ListItem {
  const _ListItem.header(this.day)
      : isHeader = true,
        entry = null;
  const _ListItem.entry(this.entry)
      : isHeader = false,
        day = null;

  final bool isHeader;
  final DateTime? day;
  final TimeEntry? entry;
}

// ── Subwidgets ─────────────────────────────────────────────────────────────

class _WeekSummaryBanner extends StatelessWidget {
  const _WeekSummaryBanner({required this.totalDuration, required this.entryCount});

  final Duration totalDuration;
  final int entryCount;

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('This Week',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer.withOpacity(0.7),
                  )),
              const SizedBox(height: 2),
              Text(
                totalDuration == Duration.zero ? '—' : _fmt(totalDuration),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Entries',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer.withOpacity(0.7),
                  )),
              const SizedBox(height: 2),
              Text(
                '$entryCount',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.projectName,
    required this.projectColor,
    required this.startMs,
    required this.endMs,
    required this.duration,
    required this.note,
    required this.formatTime,
    required this.formatDuration,
    required this.onTap,
  });

  final String projectName;
  final Color projectColor;
  final int startMs;
  final int? endMs;
  final Duration duration;
  final String? note;
  final String Function(int) formatTime;
  final String Function(Duration) formatDuration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeRange = endMs != null
        ? '${formatTime(startMs)} – ${formatTime(endMs!)}'
        : '${formatTime(startMs)} – ongoing';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Colored project dot
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: projectColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              // Project name + note
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      projectName,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (note != null && note!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        note!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.55)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Time range + duration
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(timeRange, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 2),
                  Text(
                    formatDuration(duration),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}