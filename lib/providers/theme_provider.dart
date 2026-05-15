// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemePrefKey = 'theme_mode';

class ThemeNotifier extends Notifier<ThemeMode> {
  static const _values = {
    'light': ThemeMode.light,
    'dark': ThemeMode.dark,
    'system': ThemeMode.system,
  };

  @override
  ThemeMode build() {
    // Load persisted value synchronously via ref.watch on the prefs provider.
    // Falls back to system if nothing is stored yet.
    final prefs = ref.watch(sharedPreferencesProvider);
    final stored = prefs.getString(_kThemePrefKey);
    return _values[stored] ?? ThemeMode.system;
  }

  void setTheme(ThemeMode mode) {
    state = mode;
    _persist(mode);
  }

  void toggle() {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    setTheme(next);
  }

  void _persist(ThemeMode mode) {
    final prefs = ref.read(sharedPreferencesProvider);
    final key = _values.entries
        .firstWhere((e) => e.value == mode)
        .key;
    prefs.setString(_kThemePrefKey, key);
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(
  ThemeNotifier.new,
);

/// Provide a pre-loaded SharedPreferences instance.
/// Initialize this in main() before runApp.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override sharedPreferencesProvider in main()');
});