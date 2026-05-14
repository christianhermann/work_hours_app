// lib/providers/active_entry_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import 'database_provider.dart';

final activeEntryProvider = StreamProvider<TimeEntry?>((ref) {
  final db = ref.watch(databaseProvider);

  return (db.select(db.timeEntries)
        ..where((t) => t.endTime.isNull()))
      .watchSingleOrNull();
});