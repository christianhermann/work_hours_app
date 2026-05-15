// lib/database/tables.dart
part of 'database.dart';

@DataClassName('Project')
class Projects extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 50)();

  TextColumn get color => text().withLength(min: 7, max: 7)();
  
  RealColumn get hourlyRate => real().nullable()();
}

@DataClassName('TimeEntry')
class TimeEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get projectId =>
      integer().references(Projects, #id, onDelete: KeyAction.cascade)();

  IntColumn get startTime => integer()();

  IntColumn get endTime => integer().nullable()();

  TextColumn get note => text().withLength(min: 0, max: 500).nullable()();
}