// lib/utils/csv_export.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../database/database.dart';

/// Lightweight pairing of a TimeEntry with its resolved Project name.
class TimeEntryWithProject {
  final TimeEntry entry;
  final String projectName;

  const TimeEntryWithProject({
    required this.entry,
    required this.projectName,
  });
}

/// Formats a duration in milliseconds as "HH:MM".
String _formatDuration(int ms) {
  final d = Duration(milliseconds: ms);
  final h = d.inHours.toString().padLeft(2, '0');
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  return '$h:$m';
}

/// Escapes a CSV cell value (wraps in quotes if it contains comma/quote/newline).
String _csvCell(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

/// Writes [entries] as a CSV to [filePath].
/// Throws on I/O errors so the caller can handle them.
Future<void> exportToCsv(
  List<TimeEntryWithProject> entries,
  String filePath,
) async {
  final dateFmt = DateFormat('yyyy-MM-dd');
  final timeFmt = DateFormat('HH:mm');

  final buffer = StringBuffer();
  buffer.writeln('Date,Project,Start Time,End Time,Duration (HH:MM),Note');

  for (final e in entries) {
    final start = DateTime.fromMillisecondsSinceEpoch(e.entry.startTime);
    final endMs = e.entry.endTime;
    final end = endMs != null
        ? DateTime.fromMillisecondsSinceEpoch(endMs)
        : null;
    final durationStr = endMs != null
        ? _formatDuration(endMs - e.entry.startTime)
        : '';

    buffer.writeln([
      _csvCell(dateFmt.format(start)),
      _csvCell(e.projectName),
      _csvCell(timeFmt.format(start)),
      _csvCell(end != null ? timeFmt.format(end) : ''),
      _csvCell(durationStr),
      _csvCell(e.entry.note ?? ''),
    ].join(','));
  }

  final file = File(filePath);
  await file.writeAsString(buffer.toString());
}

/// Resolves the export file path (Downloads on Android, Documents elsewhere).
Future<String> resolveExportPath(String fileName) async {
  if (Platform.isAndroid) {
    // /storage/emulated/0/Download is the standard public Downloads folder.
    const downloadsPath = '/storage/emulated/0/Download';
    final dir = Directory(downloadsPath);
    if (await dir.exists()) {
      return '$downloadsPath/$fileName';
    }
  }
  // Fallback: app documents directory (works on iOS and desktop too).
  final dir = await getApplicationDocumentsDirectory();
  return '${dir.path}/$fileName';
}

/// Orchestrates export and shows a [SnackBar] with the result.
/// Call this from a [BuildContext] that has a [ScaffoldMessenger] ancestor.
Future<void> runCsvExport(
  BuildContext context,
  List<TimeEntryWithProject> entries,
) async {
  final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
  final fileName = 'work_hours_$timestamp.csv';

  try {
    final filePath = await resolveExportPath(fileName);
    await exportToCsv(entries, filePath);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported to $filePath'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}