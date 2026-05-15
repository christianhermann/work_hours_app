// lib/screens/project_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:intl/intl.dart';

import '../database/database.dart';
import '../providers/project_list_provider.dart';
import '../providers/database_provider.dart';

// ─── Provider: raw entries per project ───────────────────────────────────────

final _projectEntriesProvider =
    StreamProvider.family<List<TimeEntry>, int>((ref, projectId) {
  final db = ref.watch(databaseProvider);
  return db.timeEntryDao.watchEntriesForProject(projectId); // uses the new stream
});

// _projectStatsProvider now reads from the stream provider
final _projectStatsProvider =
    StreamProvider.family<({int entryCount, double totalHours}), int>(
  (ref, projectId) async* {
    final entriesStream = ref.watch(_projectEntriesProvider(projectId).stream);
    await for (final entries in entriesStream) {
      final completed = entries.where((e) => e.endTime != null).toList();
      double totalMs = 0;
      for (final e in completed) {
        totalMs += (e.endTime! - e.startTime).toDouble();
      }
      yield (
        entryCount: completed.length,
        totalHours: totalMs / (1000 * 60 * 60),
      );
    }
  },
);

// ─── Screen ───────────────────────────────────────────────────────────────────

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProjects = ref.watch(projectListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProjectSheet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: asyncProjects.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (projects) => projects.isEmpty
            ? const Center(child: Text('No projects yet. Tap + to add one.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: projects.length,
                itemBuilder: (context, index) =>
                    _ProjectCard(project: projects[index]),
              ),
      ),
    );
  }
}

// ─── Project Card ─────────────────────────────────────────────────────────────

class _ProjectCard extends ConsumerWidget {
  const _ProjectCard({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectColor = _parseHexColor(project.color);
    final statsAsync = ref.watch(_projectStatsProvider(project.id));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey('project_${project.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.error,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child:
              Icon(Icons.delete, color: Theme.of(context).colorScheme.onError),
        ),
        confirmDismiss: (_) => _confirmDelete(context, project.name),
        onDismissed: (_) =>
            ref.read(projectListProvider.notifier).deleteProject(project.id),
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            // ← tap opens the measurements sheet
            onTap: () => _showMeasurementsSheet(context, ref, project),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              leading: CircleAvatar(
                backgroundColor: projectColor,
                child: Text(
                  _initials(project.name),
                  style: TextStyle(
                    color: _foregroundFor(projectColor),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              title: Text(project.name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: statsAsync.when(
                  loading: () => const Text('…'),
                  error: (_, _) => const Text('—'),
                  data: (stats) => Text(
                    _buildSubtitle(
                      entryCount: stats.entryCount,
                      totalHours: stats.totalHours,
                      hourlyRate: project.hourlyRate,
                    ),
                    style: TextStyle(
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ),
              trailing: PopupMenuButton<_Action>(
                onSelected: (action) async {
                  switch (action) {
                    case _Action.edit:
                      await _showProjectSheet(context, ref, project: project);
                    case _Action.delete:
                      final ok = await _confirmDelete(context, project.name);
                      if (ok) {
                        ref
                            .read(projectListProvider.notifier)
                            .deleteProject(project.id);
                      }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: _Action.edit, child: Text('Edit')),
                  PopupMenuItem(value: _Action.delete, child: Text('Delete')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _Action { edit, delete }

// ─── Measurements Sheet ───────────────────────────────────────────────────────

void _showMeasurementsSheet(
    BuildContext context, WidgetRef ref, Project project) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _MeasurementsSheet(project: project),
  );
}

class _MeasurementsSheet extends ConsumerWidget {
  const _MeasurementsSheet({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _parseHexColor(project.color);
    final entriesAsync = ref.watch(_projectEntriesProvider(project.id)); // same call, works with StreamProvider too

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            // ── Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 42, height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: color,
                        child: Text(_initials(project.name),
                            style: TextStyle(
                                color: _foregroundFor(color),
                                fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(project.name,
                            style: Theme.of(context).textTheme.titleLarge),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                ],
              ),
            ),
            // ── Entry list ──────────────────────────────────────
            Expanded(
              child: entriesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (entries) {
                  final completed =
                      entries.where((e) => e.endTime != null).toList();
                  if (completed.isEmpty) {
                    return const Center(
                        child: Text('No completed measurements yet.'));
                  }
                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: completed.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) => _MeasurementTile(
                      entry: completed[index],
                      onChanged: () =>
                          ref.refresh(_projectEntriesProvider(project.id)),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Measurement Tile ─────────────────────────────────────────────────────────

class _MeasurementTile extends StatelessWidget {
  const _MeasurementTile({required this.entry, required this.onChanged});

  final TimeEntry entry;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final start = DateTime.fromMillisecondsSinceEpoch(entry.startTime);
    final end = DateTime.fromMillisecondsSinceEpoch(entry.endTime!);
    final duration = end.difference(start);

    final dateFmt = DateFormat('EEE, dd MMM yyyy');
    final timeFmt = DateFormat('HH:mm');

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      title: Text(dateFmt.format(start),
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            const Icon(Icons.play_arrow_rounded, size: 14),
            const SizedBox(width: 2),
            Text(timeFmt.format(start)),
            const SizedBox(width: 12),
            const Icon(Icons.stop_rounded, size: 14),
            const SizedBox(width: 2),
            Text(timeFmt.format(end)),
            const SizedBox(width: 12),
            const Icon(Icons.timer_outlined, size: 14),
            const SizedBox(width: 2),
            Text(_fmtDuration(duration)),
          ],
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () async {
              await showDialog<void>(
                context: context,
                builder: (_) => _EditEntryDialog(entry: entry),
              );
              onChanged: () {}; // stream auto-updates; no manual refresh needed
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            color: Theme.of(context).colorScheme.error,
            onPressed: () async {
              final ok = await _confirmDeleteEntry(context);
              if (ok && context.mounted) {
                final db = ProviderScope.containerOf(context)
                    .read(databaseProvider);
                await db.timeEntryDao.deleteTimeEntry(entry.id);
                onChanged();
              }
            },
          ),
        ],
      ),
    );
  }
}

// ─── Edit Entry Dialog ────────────────────────────────────────────────────────

class _EditEntryDialog extends ConsumerStatefulWidget {
  const _EditEntryDialog({required this.entry});
  final TimeEntry entry;

  @override
  ConsumerState<_EditEntryDialog> createState() => _EditEntryDialogState();
}

class _EditEntryDialogState extends ConsumerState<_EditEntryDialog> {
  late DateTime _start;
  late DateTime _end;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _start = DateTime.fromMillisecondsSinceEpoch(widget.entry.startTime);
    _end = DateTime.fromMillisecondsSinceEpoch(widget.entry.endTime!);
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initial = isStart ? _start : _end;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;

    final picked =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (!mounted) return;
    setState(() => isStart ? _start = picked : _end = picked);
  }

  Future<void> _save() async {
    if (!_end.isAfter(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time.')),
      );
      return;
    }
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    await db.timeEntryDao.updateTimeEntry(
      widget.entry.copyWith(
        startTime: _start.millisecondsSinceEpoch,
        endTime: Value(_end.millisecondsSinceEpoch),
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy');
    final timeFmt = DateFormat('HH:mm');
    final duration = _end.difference(_start);

    return AlertDialog(
      title: const Text('Edit Measurement'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DateTimeRow(
            label: 'Start',
            icon: Icons.play_arrow_rounded,
            dateText: dateFmt.format(_start),
            timeText: timeFmt.format(_start),
            onTap: () => _pickDateTime(isStart: true),
          ),
          const SizedBox(height: 12),
          _DateTimeRow(
            label: 'End',
            icon: Icons.stop_rounded,
            dateText: dateFmt.format(_end),
            timeText: timeFmt.format(_end),
            onTap: () => _pickDateTime(isStart: false),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 16),
              const SizedBox(width: 6),
              Text('Duration: ${_fmtDuration(duration)}',
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _DateTimeRow extends StatelessWidget {
  const _DateTimeRow({
    required this.label,
    required this.icon,
    required this.dateText,
    required this.timeText,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final String dateText;
  final String timeText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            SizedBox(
              width: 44,
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Expanded(child: Text(dateText)),
            Text(
              timeText,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.edit, size: 14),
          ],
        ),
      ),
    );
  }
}

// ─── Project Editor Sheet (unchanged logic) ───────────────────────────────────

Future<void> _showProjectSheet(
  BuildContext context,
  WidgetRef ref, {
  Project? project,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ProjectEditorSheet(project: project),
  );
}

class _ProjectEditorSheet extends ConsumerStatefulWidget {
  const _ProjectEditorSheet({this.project});
  final Project? project;

  @override
  ConsumerState<_ProjectEditorSheet> createState() =>
      _ProjectEditorSheetState();
}

class _ProjectEditorSheetState extends ConsumerState<_ProjectEditorSheet> {
  static const _presetColors = <Color>[
    Color(0xFFEF5350), Color(0xFFEC407A), Color(0xFFAB47BC),
    Color(0xFF7E57C2), Color(0xFF5C6BC0), Color(0xFF42A5F5),
    Color(0xFF29B6F6), Color(0xFF26C6DA), Color(0xFF26A69A),
    Color(0xFF66BB6A), Color(0xFFFFCA28), Color(0xFFFFA726),
    Color(0xFFFF7043), Color(0xFF8D6E63),
  ];

  late final TextEditingController _nameCtrl;
  late final TextEditingController _rateCtrl;
  late Color _color;
  bool _saving = false;

  bool get _isEditing => widget.project != null;

  @override
  void initState() {
    super.initState();
    final p = widget.project;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _rateCtrl =
        TextEditingController(text: p?.hourlyRate?.toString() ?? '');
    _color = p != null ? _parseHexColor(p.color) : _presetColors.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42, height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(_isEditing ? 'Edit Project' : 'Add Project',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                  labelText: 'Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Text('Color', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12, runSpacing: 12,
              children: _presetColors.map((c) {
                final selected = c == _color;
                return GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? Theme.of(context).colorScheme.onSurface
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: selected
                        ? Icon(Icons.check, color: _foregroundFor(c), size: 20)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _rateCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Hourly rate (optional)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_isEditing ? 'Save' : 'Add'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final rateText = _rateCtrl.text.trim().replaceAll(',', '.');
    final rate = rateText.isEmpty ? null : double.tryParse(rateText);
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a project name.')));
      return;
    }
    if (rateText.isNotEmpty && rate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid hourly rate.')));
      return;
    }
    setState(() => _saving = true);
    final red = (_color.r * 255.0).round().clamp(0, 255).toInt();
    final green = (_color.g * 255.0).round().clamp(0, 255).toInt();
    final blue = (_color.b * 255.0).round().clamp(0, 255).toInt();
    final hexColor = ((red << 16) | (green << 8) | blue)
        .toRadixString(16)
        .padLeft(6, '0')
        .toUpperCase();
    final notifier = ref.read(projectListProvider.notifier);
    if (_isEditing) {
      await notifier.updateProject(widget.project!.copyWith(
          name: name, color: hexColor, hourlyRate: Value(rate)));
    } else {
      await notifier.addProject(ProjectsCompanion.insert(
          name: name, color: hexColor, hourlyRate: Value(rate)));
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }
}

// ─── Pure helpers ─────────────────────────────────────────────────────────────

Future<bool> _confirmDelete(BuildContext context, String name) async {
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete project?'),
          content: Text('Delete "$name"? This cannot be undone.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete')),
          ],
        ),
      ) ??
      false;
}

Future<bool> _confirmDeleteEntry(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete measurement?'),
          content: const Text('This entry will be permanently deleted.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete')),
          ],
        ),
      ) ??
      false;
}

Color _parseHexColor(String hex) {
  final cleaned = hex.replaceFirst('#', '');
  if (cleaned.length == 6) return Color(int.parse('FF$cleaned', radix: 16));
  if (cleaned.length == 8) return Color(int.parse(cleaned, radix: 16));
  return const Color(0xFF42A5F5);
}

Color _foregroundFor(Color c) =>
    c.computeLuminance() > 0.5 ? Colors.black : Colors.white;

String _initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts[0].characters.first + parts[1].characters.first).toUpperCase();
}

String _buildSubtitle({
  required int entryCount,
  required double totalHours,
  required double? hourlyRate,
}) {
  final label = entryCount == 1 ? '1 entry' : '$entryCount entries';
  final hours = '${_fmtNum(totalHours)} h';
  if (hourlyRate == null) return '$label • $hours';
  return '$label • $hours • ${_fmtNum(hourlyRate)}/h';
}

String _fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
  if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
  return '${s}s';
}

String _fmtNum(double v) {
  if (v == v.truncateToDouble()) return v.toStringAsFixed(0);
  final s = v.toStringAsFixed(2);
  return s.endsWith('0') ? v.toStringAsFixed(1) : s;
}