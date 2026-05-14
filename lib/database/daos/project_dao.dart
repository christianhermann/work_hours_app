// lib/database/daos/project_dao.dart
part of '../database.dart';

@DriftAccessor(tables: [Projects])
class ProjectDao extends DatabaseAccessor<AppDatabase> with _$ProjectDaoMixin {
  ProjectDao(super.db);

  Future<int> insertProject(ProjectsCompanion project) {
    return into(projects).insert(project);
  }

  Future<bool> updateProject(Project project) {
    return update(projects).replace(project);
  }

  Future<int> deleteProject(int id) {
    return (delete(projects)..where((tbl) => tbl.id.equals(id))).go();
  }

  Future<List<Project>> getAllProjects() {
    return (select(projects)
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)]))
        .get();
  }

  Future<Project?> getProjectById(int id) {
    return (select(projects)..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }
}