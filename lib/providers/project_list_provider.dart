// lib/providers/project_list_provider.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import 'database_provider.dart';

class ProjectListNotifier extends AsyncNotifier<List<Project>> {
  @override
  Future<List<Project>> build() async {
    final db = ref.watch(databaseProvider);
    return db.select(db.projects).get();
  }

  Future<void> addProject(ProjectsCompanion projectCompanion) async {
    final db = ref.read(databaseProvider);
    await db.into(db.projects).insert(projectCompanion);
    // Invalidating self triggers a re-run of the build() method, updating listeners
    ref.invalidateSelf();
  }

  Future<void> updateProject(Project project) async {
    final db = ref.read(databaseProvider);
    await db.update(db.projects).replace(project);
    ref.invalidateSelf();
  }

  Future<void> deleteProject(int id) async {
    final db = ref.read(databaseProvider);
    await (db.delete(db.projects)..where((tbl) => tbl.id.equals(id))).go();
    ref.invalidateSelf();
  }
}

final projectListProvider = AsyncNotifierProvider<ProjectListNotifier, List<Project>>(
  ProjectListNotifier.new,
);