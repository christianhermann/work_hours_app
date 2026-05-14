// lib/providers/today_entries_provider.dart

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import 'database_provider.dart';

final todayEntriesProvider = StreamProvider<List<TimeEntry>>((ref) {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  final startOfTomorrow = startOfDay.add(const Duration(days: 1));
  final startMs = startOfDay.toUtc().millisecondsSinceEpoch;
  final endMs = startOfTomorrow.toUtc().millisecondsSinceEpoch;

  return (db.select(db.timeEntries)
        ..where((t) => t.startTime.isBiggerOrEqualValue(startMs))
        ..where((t) => t.startTime.isSmallerThanValue(endMs))
        ..orderBy([(t) => OrderingTerm(expression: t.startTime, mode: OrderingMode.desc)]))
      .watch();
});