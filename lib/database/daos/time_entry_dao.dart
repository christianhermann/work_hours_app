// lib/database/daos/time_entry_dao.dart
part of '../database.dart';

@DriftAccessor(tables: [TimeEntries, Projects])
class TimeEntryDao extends DatabaseAccessor<AppDatabase>
    with _$TimeEntryDaoMixin {
  TimeEntryDao(super.db);

  Future<int> insertTimeEntry(TimeEntriesCompanion entry) {
    return into(timeEntries).insert(entry);
  }

  Future<bool> updateTimeEntry(TimeEntry entry) {
    return update(timeEntries).replace(entry);
  }

  Future<int> deleteTimeEntry(int id) {
    return (delete(timeEntries)..where((tbl) => tbl.id.equals(id))).go();
  }

  Future<List<TimeEntry>> getEntriesForProject(int projectId) {
    return (select(timeEntries)
          ..where((tbl) => tbl.projectId.equals(projectId))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.startTime)]))
        .get();
  }

  Future<List<TimeEntry>> getEntriesForDateRange(
    DateTime start,
    DateTime end,
  ) {
    final startUtc = start.toUtc().millisecondsSinceEpoch;
    final endUtc = end.toUtc().millisecondsSinceEpoch;

    return (select(timeEntries)
          ..where(
            (tbl) =>
                tbl.startTime.isBiggerOrEqualValue(startUtc) &
                tbl.startTime.isSmallerOrEqualValue(endUtc),
          )
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.startTime)]))
        .get();
  }

  Future<TimeEntry?> getRunningEntry() {
    return (select(timeEntries)
          ..where((tbl) => tbl.endTime.isNull())
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.startTime)])
          ..limit(1))
        .getSingleOrNull();
  }
}