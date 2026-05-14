@echo off
cd /d "C:\Users\Christian\Documents\work_hours_app\lib"

REM Create directories
mkdir database 2>nul
mkdir models 2>nul
mkdir providers 2>nul
mkdir screens 2>nul
mkdir widgets 2>nul

REM Create database files
(
echo // Drift database definition
echo import 'package:drift/drift.dart';
echo import 'package:drift/native.dart';
echo import 'dart:io';
echo import 'package:path/path.dart' as p;
echo import 'package:path_provider/path_provider.dart';
echo import 'tables.dart';
echo.
echo part 'database.g.dart';
echo.
echo @DriftDatabase^(tables: [ProjectTable, TimeEntryTable]^)
echo class AppDatabase extends _$AppDatabase {
echo   AppDatabase^(^) : super^(_openConnection^(^^)^);
echo.
echo   @override
echo   int get schemaVersion =^> 1;
echo }
echo.
echo LazyDatabase _openConnection^(^) {
echo   return LazyDatabase^(^(^) async {
echo     final dbFolder = await getApplicationDocumentsDirectory^(^^)^);
echo     final file = File^(p.join^(dbFolder.path, 'db.sqlite'^)^);
echo     return NativeDatabase^(file^);
echo   }^);
echo }
) > database\database.dart

REM Create tables file
(
echo // Drift table definitions
echo import 'package:drift/drift.dart';
echo.
echo @DataClassName^('Project'^)
echo class ProjectTable extends Table {
echo   IntColumn get id =^> integer^(^^)^).autoIncrement^(^^)^^)^);
echo   TextColumn get name =^> text^(^^)^).withLength^(min: 1, max: 255^^)^^)^);
echo   TextColumn get description =^> text^(^^)^).nullable^(^^)^^)^);
echo   DateTimeColumn get createdAt =^> dateTime^(^^)^^)^);
echo }
echo.
echo @DataClassName^('TimeEntry'^)
echo class TimeEntryTable extends Table {
echo   IntColumn get id =^> integer^(^^)^).autoIncrement^(^^)^^)^);
echo   IntColumn get projectId =^> integer^(^^)^).references^(ProjectTable, #id^^)^^)^);
echo   DateTimeColumn get startTime =^> dateTime^(^^)^^)^);
echo   DateTimeColumn get endTime =^> dateTime^(^^)^).nullable^(^^)^^)^);
echo   TextColumn get notes =^> text^(^^)^).nullable^(^^)^^)^);
echo }
) > database\tables.dart

echo Directory structure and files created successfully!
