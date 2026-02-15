import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../constants/app_config.dart';
import 'shared_prefs_service.dart';

part 'accessibility_modes.g.dart';

enum InteractionMode {
  scan,
  text,
}

@riverpod
class SilenceMode extends _$SilenceMode {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(AppConfig.silenceModeEnabledKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(AppConfig.silenceModeEnabledKey, enabled);
    state = enabled;
  }

  Future<void> toggle() async {
    await setEnabled(!state);
  }
}

@riverpod
class InteractionModeState extends _$InteractionModeState {
  @override
  InteractionMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(AppConfig.interactionModeKey);
    return raw == InteractionMode.text.name
        ? InteractionMode.text
        : InteractionMode.scan;
  }

  Future<void> setMode(InteractionMode mode) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(AppConfig.interactionModeKey, mode.name);
    state = mode;
  }

  Future<void> toggle() async {
    final next = state == InteractionMode.scan
        ? InteractionMode.text
        : InteractionMode.scan;
    await setMode(next);
  }
}
