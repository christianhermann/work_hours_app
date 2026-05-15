// lib/database/database.dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'tables.dart';
part 'daos/project_dao.dart';
part 'daos/time_entry_dao.dart';
part 'database.g.dart';

@DriftDatabase(
  tables: [Projects, TimeEntries],
  daos: [ProjectDao, TimeEntryDao],
)
class AppDatabase extends _$AppDatabase {
  /// Always constructed with an explicit executor (injected via databaseProvider).
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // Add future migration steps here as schemaVersion increases.
      // Example for v2:
      // if (from < 2) {
      //   await m.addColumn(timeEntries, timeEntries.someNewColumn);
      // }
    },
    beforeOpen: (details) async {
      // Enforce FK constraints on every connection (SQLite disables them by default).
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}