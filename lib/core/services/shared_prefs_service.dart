import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_config.dart';

part 'shared_prefs_service.g.dart';

@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(Ref ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
}

@riverpod
class RiskAcceptance extends _$RiskAcceptance {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(AppConfig.hasAcceptedRisksKey) ?? false;
  }

  Future<void> accept() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(AppConfig.hasAcceptedRisksKey, true);
    state = true;
  }
}
