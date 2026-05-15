// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../database/database.dart';
import '../providers/database_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/csv_export.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  // Loads all time entries joined with their project names.
  Future<List<TimeEntryWithProject>> _loadAllEntries(AppDatabase db) async {
    final entries = await db.select(db.timeEntries).get();
    final projects = await db.select(db.projects).get();
    final projectMap = {for (final p in projects) p.id: p.name};

    return entries
        .map((e) => TimeEntryWithProject(
              entry: e,
              projectName: projectMap[e.projectId] ?? 'Unknown',
            ))
        .toList();
  }

  Future<void> _showAboutDialog(BuildContext context) async {
    // package_info_plus is a common transitive dep; gracefully fall back if not available.
    String version = 'N/A';
    String buildNumber = 'N/A';
    try {
      final info = await PackageInfo.fromPlatform();
      version = info.version;
      buildNumber = info.buildNumber;
    } catch (_) {}

    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('About'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Work Hours Tracker',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Version: $version'),
            Text('Build: $buildNumber'),
            const SizedBox(height: 8),
            const Text('Offline-only time tracking app.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final db = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_4_outlined),
            onPressed: () => ref.read(themeProvider.notifier).toggle(),
          ),
        ],
      ),
      body: ListView(
        children: [
          // ── Export CSV ──────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Export CSV'),
            subtitle: const Text('Save all entries to Downloads folder'),
            onTap: () async {
              final entries = await _loadAllEntries(db);
              if (context.mounted) {
                await runCsvExport(context, entries);
              }
            },
          ),
          const Divider(),

          // ── Dark Mode ───────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text('Dark Mode'),
            trailing: Switch(
              value: themeMode == ThemeMode.dark,
              onChanged: (val) =>
                  ref.read(themeProvider.notifier).toggle(),
            ),
          ),
          const Divider(),

          // ── About ───────────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            onTap: () => _showAboutDialog(context),
          ),
        ],
      ),
    );
  }
}