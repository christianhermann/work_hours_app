// lib/screens/timer_screen.dart
import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../providers/database_provider.dart';
import '../providers/project_list_provider.dart';
import '../providers/timer_session_provider.dart';
import '../providers/active_entry_provider.dart';
import '../providers/today_entries_provider.dart';

class TimerScreen extends ConsumerStatefulWidget {
  const TimerScreen({super.key});

  @override
  ConsumerState<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends ConsumerState<TimerScreen> {
  Timer? _ticker;
  int? _selectedProjectId;

  @override
  void initState() {
    super.initState();
    _startTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Duration _currentElapsed({
    required dynamic timerSession,
    required TimeEntry? activeEntry,
  }) {
    if (timerSession != null) {
      final dynamic startedAt = timerSession.startTime;
      if (startedAt is int) {
        return DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(startedAt));
      } else if (startedAt is DateTime) {
        return DateTime.now().difference(startedAt);
      }
    }

    if (activeEntry != null) {
      final startMs = activeEntry.startTime;
      return DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(startMs));
        }

    return Duration.zero;
  }

  String _formatDigital(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final hours = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String _formatSaved(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    }
    if (hours > 0) {
      return '${hours}h';
    }
    return '${minutes}m';
  }

  Future<void> _handleStart() async {
    final projectsAsync = ref.read(projectListProvider);

    final projects = projectsAsync.maybeWhen(
      data: (data) => data,
      orElse: () => <dynamic>[],
    );

    if (projects.isEmpty) {
      if (!mounted) return;
      material.ScaffoldMessenger.of(context).showSnackBar(
        const material.SnackBar(content: material.Text('Create a project first.')),
      );
      return;
    }

    final selectedId = _selectedProjectId ?? projects.first.id;

    final selectedProject = projects.cast<dynamic>().firstWhere(
          (p) => p.id == selectedId,
          orElse: () => projects.first,
        );

    final notifier = ref.read(timerSessionProvider.notifier);

    notifier.startTimer(
      projectId: selectedProject.id as int
    );
    }

  Future<void> _handleStop() async {
    final db = ref.read(databaseProvider);
    final activeEntry = ref.read(activeEntryProvider).valueOrNull;
    final timerSession = ref.read(timerSessionProvider);

    DateTime? startTime;

    final dynamic rawStart = timerSession.startTime;
    if (rawStart is DateTime) {
      startTime = rawStart;
    } else if (rawStart is int) {
      startTime = DateTime.fromMillisecondsSinceEpoch(rawStart);
    }
  
    if (startTime == null && activeEntry != null) {
      final activeStart = activeEntry.startTime;
      startTime = DateTime.fromMillisecondsSinceEpoch(activeStart);
        }

    if (startTime == null) {
      if (!mounted) return;
      material.ScaffoldMessenger.of(context).showSnackBar(
        const material.SnackBar(content: material.Text('No active timer found.')),
      );
      return;
    }

    final endTime = DateTime.now();
    final elapsed = endTime.difference(startTime);

    final projects = ref.read(projectListProvider).valueOrNull ?? <dynamic>[];
    final activeProjectId = activeEntry?.projectId ??
        timerSession.selectedProjectId ??
        _selectedProjectId;

    final activeProject = projects.cast<dynamic>().firstWhere(
          (p) => p?.id == activeProjectId,
          orElse: () => null,
        );

    await db.into(db.timeEntries).insert(
          TimeEntriesCompanion.insert(
            projectId: activeProjectId!,
            startTime: startTime.millisecondsSinceEpoch,
            endTime: Value(endTime.millisecondsSinceEpoch),
          ),
        );

    final notifier = ref.read(timerSessionProvider.notifier);
    notifier.stopTimer();
  
    ref.invalidate(todayEntriesProvider);
    ref.invalidate(activeEntryProvider);

    if (!mounted) return;

    final projectName = (activeProject?.name as String?) ?? 'Project';
    final savedText = _formatSaved(elapsed);

    material.ScaffoldMessenger.of(context).showSnackBar(
      material.SnackBar(content: material.Text('Saved $savedText to $projectName')),
    );
  }

  @override
  material.Widget build(material.BuildContext context) {
    final theme = material.Theme.of(context);
    final projectsAsync = ref.watch(projectListProvider);
    final timerSession = ref.watch(timerSessionProvider);
    final activeEntryAsync = ref.watch(activeEntryProvider);

    final bool isRunning = timerSession.isRunning;    final elapsed = _currentElapsed(
      timerSession: timerSession,
      activeEntry: activeEntryAsync.valueOrNull,
    );

    return material.Scaffold(
      appBar: material.AppBar(
        title: const material.Text('Work Hours'),
      ),
      body: material.SafeArea(
        child: projectsAsync.when(
          data: (projects) {
            if (!isRunning &&
                projects.isNotEmpty &&
                (_selectedProjectId == null ||
                    !projects.any((p) => p.id == _selectedProjectId))) {
              _selectedProjectId = projects.first.id;
            }

            final activeProjectId = activeEntryAsync.valueOrNull?.projectId ??
                timerSession.selectedProjectId ??
                _selectedProjectId;

            return material.Center(
              child: material.ConstrainedBox(
                constraints: const material.BoxConstraints(maxWidth: 420),
                child: material.Padding(
                  padding: const material.EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: material.Column(
                    mainAxisAlignment: material.MainAxisAlignment.center,
                    children: [
                      material.Text(
                        _formatDigital(elapsed),
                        style: theme.textTheme.displayMedium?.copyWith(
                          fontWeight: material.FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const material.SizedBox(height: 32),
                      _TimerActionButton(
                        isRunning: isRunning,
                        onPressed: isRunning ? _handleStop : _handleStart,
                      ),
                      const material.SizedBox(height: 28),
                      material.DropdownButtonFormField<int>(
                        initialValue: activeProjectId,
                        decoration: const material.InputDecoration(
                          labelText: 'Project',
                          border: material.OutlineInputBorder(),
                        ),
                        items: projects
                            .map(
                              (project) => material.DropdownMenuItem<int>(
                                value: project.id,
                                child: material.Text(project.name),
                              ),
                            )
                            .toList(),
                        onChanged: isRunning
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedProjectId = value;
                                });
                              },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          loading: () => const material.Center(
            child: material.CircularProgressIndicator(),
          ),
          error: (error, stackTrace) => material.Center(
            child: material.Padding(
              padding: const material.EdgeInsets.all(24),
              child: material.  Text(
                'Failed to load projects.',
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimerActionButton extends material.StatelessWidget {
  const _TimerActionButton({
    required this.isRunning,
    required this.onPressed,
  });

  final bool isRunning;
  final material.VoidCallback onPressed;

 @override
  material.Widget build(material.BuildContext context) {
    final color = isRunning ? material.Colors.red : material.Colors.green;
    final icon = isRunning
        ? material.Icons.stop_rounded
        : material.Icons.play_arrow_rounded;

    return material.SizedBox(
      width: 148,
      height: 148,
      child: material.FilledButton(
        onPressed: onPressed,
        style: material.FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: material.Colors.white,
          shape: const material.CircleBorder(),
          elevation: 0,
        ),
        child: material.Icon(icon, size: 56),
      ),
    );
  }
}