// lib/providers/timer_session_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

class TimerSessionState {
  final bool isRunning;
  final DateTime? startTime;
  final int? selectedProjectId;

  const TimerSessionState({
    this.isRunning = false,
    this.startTime,
    this.selectedProjectId,
  });

  /// Dynamically calculates the elapsed time. Call this periodically via a Ticker/Timer in the UI.
  Duration? get elapsed {
    if (!isRunning || startTime == null) return null;
    return DateTime.now().difference(startTime!);
  }

  TimerSessionState copyWith({
    bool? isRunning,
    DateTime? startTime,
    int? selectedProjectId,
  }) {
    return TimerSessionState(
      isRunning: isRunning ?? this.isRunning,
      startTime: startTime ?? this.startTime,
      selectedProjectId: selectedProjectId ?? this.selectedProjectId,
    );
  }
}

class TimerSessionNotifier extends Notifier<TimerSessionState> {
  @override
  TimerSessionState build() => const TimerSessionState();

  void startTimer({required int projectId}) {
    state = state.copyWith(
      isRunning: true,
      startTime: DateTime.now(),
      selectedProjectId: projectId,
    );
  }

  void stopTimer() {
    state = state.copyWith(isRunning: false);
  }

  void resetTimer() {
    state = const TimerSessionState(); // Reset back to initial state
  }
}

final timerSessionProvider = NotifierProvider<TimerSessionNotifier, TimerSessionState>(
  TimerSessionNotifier.new,
);