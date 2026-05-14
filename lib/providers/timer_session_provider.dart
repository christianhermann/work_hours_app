// Active session state provider
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
