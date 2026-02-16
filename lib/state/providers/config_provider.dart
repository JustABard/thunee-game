import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/game_config.dart';
import '../../data/repositories/settings_repository.dart';

/// Provider for SharedPreferences instance
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden in main()');
});

/// Provider for SettingsRepository
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsRepository(prefs);
});

/// Provider for game configuration with persistence
class ConfigNotifier extends StateNotifier<GameConfig> {
  final SettingsRepository _repository;

  ConfigNotifier(this._repository) : super(_repository.loadSettings());

  /// Updates configuration and persists it
  Future<void> updateConfig(GameConfig config) async {
    state = config;
    await _repository.saveSettings(config);
  }

  /// Updates a single setting
  Future<void> updateSetting({
    bool? enableRoyals,
    bool? enableBlindThunee,
    bool? enableBlindRoyals,
    bool? enableKunuck,
    bool? enableFirstThirdOnlyJodiCalls,
    bool? enableCallOverTeammates,
    bool? enableCallAndLoss,
    int? blindThuneeSuccessBalls,
    int? blindRoyalsSuccessBalls,
    int? matchTarget,
  }) async {
    final newConfig = GameConfig(
      enableRoyals: enableRoyals ?? state.enableRoyals,
      enableBlindThunee: enableBlindThunee ?? state.enableBlindThunee,
      enableBlindRoyals: enableBlindRoyals ?? state.enableBlindRoyals,
      enableKunuck: enableKunuck ?? state.enableKunuck,
      enableFirstThirdOnlyJodiCalls: enableFirstThirdOnlyJodiCalls ?? state.enableFirstThirdOnlyJodiCalls,
      enableCallOverTeammates: enableCallOverTeammates ?? state.enableCallOverTeammates,
      enableCallAndLoss: enableCallAndLoss ?? state.enableCallAndLoss,
      blindThuneeSuccessBalls: blindThuneeSuccessBalls ?? state.blindThuneeSuccessBalls,
      blindRoyalsSuccessBalls: blindRoyalsSuccessBalls ?? state.blindRoyalsSuccessBalls,
      matchTarget: matchTarget ?? state.matchTarget,
    );

    await updateConfig(newConfig);
  }

  /// Resets to default settings
  Future<void> resetToDefaults() async {
    await _repository.resetToDefaults();
    state = _repository.loadSettings();
  }
}

/// Provider for game configuration notifier
final configProvider = StateNotifierProvider<ConfigNotifier, GameConfig>((ref) {
  final repository = ref.watch(settingsRepositoryProvider);
  return ConfigNotifier(repository);
});
