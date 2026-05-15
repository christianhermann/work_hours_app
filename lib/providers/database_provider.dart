// lib/providers/database_provider.dart

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../database/database.dart'; // Adjust path if necessary

/// Lazily creates and exposes the AppDatabase instance.
final databaseProvider = Provider<AppDatabase>((ref) {
  final lazyDatabase = LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'work_hours_db.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
  
  // Assumes AppDatabase takes a QueryExecutor via constructor injection.
  final db = AppDatabase(lazyDatabase);
  
  ref.onDispose(() {
    db.close();
  });
  
  return db;
});