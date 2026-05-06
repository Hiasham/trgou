import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppSettingsState {
  final int? configuredSeed;
  final bool debugEnabled;

  const AppSettingsState({
    required this.configuredSeed,
    required this.debugEnabled,
  });

  AppSettingsState copyWith({
    Object? configuredSeed = _unset,
    bool? debugEnabled,
  }) {
    return AppSettingsState(
      configuredSeed: configuredSeed == _unset
          ? this.configuredSeed
          : configuredSeed as int?,
      debugEnabled: debugEnabled ?? this.debugEnabled,
    );
  }

  static const Object _unset = Object();
}

class AppSettingsController extends StateNotifier<AppSettingsState> {
  AppSettingsController()
      : super(const AppSettingsState(configuredSeed: null, debugEnabled: false));

  void updateSeed(int? seed) {
    state = state.copyWith(configuredSeed: seed);
  }

  void setDebugEnabled(bool enabled) {
    state = state.copyWith(debugEnabled: enabled);
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsController, AppSettingsState>(
  (ref) => AppSettingsController(),
);
