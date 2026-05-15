// lib/screens/projects_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;

import '../database/database.dart';
import '../providers/project_list_provider.dart';
import '../providers/database_provider.dart';

// ─── Helper: per-project stats fetched from timeEntryDao ─────────────────────

final _projectStatsProvider =
    StreamProvider.family<({int entryCount, double totalHours}), int>(
  (ref, projectId) {
    final db = ref.watch(databaseProvider);
    return db.timeEntryDao.watchEntriesForProject(projectId).map((entries) {
      final completed = entries.where((e) => e.endTime != null).toList();
      double totalMs = 0;
      for (final e in completed) {
        totalMs += (e.endTime! - e.startTime).toDouble();
      }
      return (
        entryCount: completed.length,
        totalHours: totalMs / (1000 * 60 * 60),
      );
    });
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
                itemBuilder: (context, index) {
                  return _ProjectCard(project: projects[index]);
                },
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
          child: Icon(
            Icons.delete,
            color: Theme.of(context).colorScheme.onError,
          ),
        ),
        confirmDismiss: (_) => _confirmDelete(context, project.name),
        onDismissed: (_) =>
            ref.read(projectListProvider.notifier).deleteProject(project.id),
        child: Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
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
            title: Text(
              project.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
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
                    color: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.color?.withValues(alpha: 0.65),
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
    );
  }
}

enum _Action { edit, delete }

// ─── Bottom Sheet ─────────────────────────────────────────────────────────────

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
    Color(0xFFEF5350),
    Color(0xFFEC407A),
    Color(0xFFAB47BC),
    Color(0xFF7E57C2),
    Color(0xFF5C6BC0),
    Color(0xFF42A5F5),
    Color(0xFF29B6F6),
    Color(0xFF26C6DA),
    Color(0xFF26A69A),
    Color(0xFF66BB6A),
    Color(0xFFFFCA28),
    Color(0xFFFFA726),
    Color(0xFFFF7043),
    Color(0xFF8D6E63),
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
    _rateCtrl = TextEditingController(text: p?.hourlyRate?.toString() ?? '');
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
            // drag handle
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _isEditing ? 'Edit Project' : 'Add Project',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text('Color', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _presetColors.map((c) {
                final selected = c.toARGB32() == _color.toARGB32();
                return GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 40,
                    height: 40,
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
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Hourly rate (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
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
        const SnackBar(content: Text('Please enter a project name.')),
      );
      return;
    }
    if (rateText.isNotEmpty && rate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid hourly rate.')),
      );
      return;
    }

    setState(() => _saving = true);

    // Color → 6-char hex string (no #) to match TextColumn(min:6, max:7)
    final hexColor =
        '#${(_color.toARGB32() & 0xFFFFFF)
            .toRadixString(16)
            .padLeft(6, '0')
            .toUpperCase()}';

    final notifier = ref.read(projectListProvider.notifier);

    if (_isEditing) {
      await notifier.updateProject(
        widget.project!.copyWith(
          name: name,
          color: hexColor,
          hourlyRate: Value(rate),
        ),
      );
    } else {
      await notifier.addProject(
        ProjectsCompanion.insert(
          name: name,
          color: hexColor,
          hourlyRate: Value(rate),
        ),
      );
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
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ??
      false;
}

/// Parses stored hex string (with or without leading #) → Color
Color _parseHexColor(String hex) {
  final cleaned = hex.replaceFirst('#', '');
  if (cleaned.length == 6) {
    return Color(int.parse('FF$cleaned', radix: 16));
  }
  if (cleaned.length == 8) {
    return Color(int.parse(cleaned, radix: 16));
  }
  return const Color(0xFF42A5F5);
}

Color _foregroundFor(Color c) =>
    c.computeLuminance() > 0.5 ? Colors.black : Colors.white;

String _initials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
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

String _fmtNum(double v) {
  if (v == v.truncateToDouble()) return v.toStringAsFixed(0);
  final s = v.toStringAsFixed(2);
  return s.endsWith('0') ? v.toStringAsFixed(1) : s;
}
