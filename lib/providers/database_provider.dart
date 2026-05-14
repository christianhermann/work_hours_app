// Riverpod provider for the Drift database
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';

final databaseProvider = Provider((ref) {
  return AppDatabase();
});
