#!/usr/bin/env python3
import os
import pathlib

base_path = pathlib.Path(r"C:\Users\Christian\Documents\work_hours_app\lib")

# Create directories
dirs = ["database", "models", "providers", "screens", "widgets"]
for d in dirs:
    (base_path / d).mkdir(parents=True, exist_ok=True)

# File contents
files_content = {
    "database/database.dart": '''// Drift database definition
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [ProjectTable, TimeEntryTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase(file);
  });
}
''',
    "database/tables.dart": '''// Drift table definitions
import 'package:drift/drift.dart';

@DataClassName('Project')
class ProjectTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

@DataClassName('TimeEntry')
class TimeEntryTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(ProjectTable, #id)();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
}
''',
    "providers/database_provider.dart": '''// Riverpod provider for the Drift database
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';

final databaseProvider = Provider((ref) {
  return AppDatabase();
});
''',
    "providers/timer_provider.dart": '''// Active session state provider
import 'package:flutter_riverpod/flutter_riverpod.dart';

final activeTimerProvider = StateNotifierProvider<ActiveTimerNotifier, ActiveTimerState?>(
  (ref) => ActiveTimerNotifier(),
);

class ActiveTimerState {
  final int projectId;
  final DateTime startTime;

  ActiveTimerState({required this.projectId, required this.startTime});
}

class ActiveTimerNotifier extends StateNotifier<ActiveTimerState?> {
  ActiveTimerNotifier() : super(null);

  void startTimer(int projectId) {
    state = ActiveTimerState(projectId: projectId, startTime: DateTime.now());
  }

  void stopTimer() {
    state = null;
  }
}
''',
    "screens/project_list_screen.dart": '''// Project list view
import 'package:flutter/material.dart';

class ProjectListScreen extends StatelessWidget {
  const ProjectListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      body: const Center(child: Text('Project List')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}
''',
    "screens/timer_screen.dart": '''// Active timer view
import 'package:flutter/material.dart';

class TimerScreen extends StatelessWidget {
  const TimerScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Timer')),
      body: const Center(child: Text('Timer Screen')),
    );
  }
}
''',
    "screens/history_screen.dart": '''// Time entry history view
import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: const Center(child: Text('History Screen')),
    );
  }
}
''',
    "screens/report_screen.dart": '''// Work hours report view
import 'package:flutter/material.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: const Center(child: Text('Report Screen')),
    );
  }
}
'''
}

# Create files
for file_path, content in files_content.items():
    full_path = base_path / file_path
    full_path.parent.mkdir(parents=True, exist_ok=True)
    with open(full_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"✓ Created: {file_path}")

# Create empty directories with .gitkeep
for d in ["models", "widgets"]:
    gitkeep = base_path / d / ".gitkeep"
    gitkeep.parent.mkdir(parents=True, exist_ok=True)
    gitkeep.touch()
    print(f"✓ Created: {d}/.gitkeep")

print("\n✓ Folder structure created successfully!")
