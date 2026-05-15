// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:work_hours_app/providers/theme_provider.dart';
import 'package:work_hours_app/screens/homescreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const WorkHoursApp(),
    ),
  );
}

class WorkHoursApp extends ConsumerWidget {
  const WorkHoursApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    const seedColor = Color(0xFF4A90D9);

    return MaterialApp(
      title: 'Work Hours',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}