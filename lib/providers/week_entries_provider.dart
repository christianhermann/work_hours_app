// lib/providers/week_entries_provider.dart

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import 'database_provider.dart';

final weekEntriesProvider = StreamProvider<List<TimeEntry>>((ref) {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  // Monday of the current week
  final startOfWeek = startOfToday.subtract(Duration(days: startOfToday.weekday - 1));
  final endOfWeek = startOfWeek.add(const Duration(days: 7));

  return (db.select(db.timeEntries)
        ..where((t) => t.startTime.isBiggerOrEqualValue(startOfWeek.millisecondsSinceEpoch))
        ..where((t) => t.startTime.isSmallerThanValue(endOfWeek.millisecondsSinceEpoch))
        ..orderBy([(t) => OrderingTerm(expression: t.startTime, mode: OrderingMode.desc)]))
      .watch();
});