import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/game_config.dart';
import '../models/settings_dto.dart';

/// Repository for persisting game settings using SharedPreferences
class SettingsRepository {
  static const String _settingsKey = 'thunee_game_settings';

  final SharedPreferences _prefs;

  SettingsRepository(this._prefs);

  /// Saves game configuration to persistent storage
  Future<void> saveSettings(GameConfig config) async {
    final dto = SettingsDto.fromConfig(config);
    final jsonString = json.encode(dto.toJson());
    await _prefs.setString(_settingsKey, jsonString);
  }

  /// Loads game configuration from persistent storage
  /// Returns default settings if none are saved
  GameConfig loadSettings() {
    final jsonString = _prefs.getString(_settingsKey);

    if (jsonString == null) {
      return SettingsDto.defaults().toConfig();
    }

    try {
      final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
      final dto = SettingsDto.fromJson(jsonMap);
      return dto.toConfig();
    } catch (e) {
      // If parsing fails, return defaults
      return SettingsDto.defaults().toConfig();
    }
  }

  /// Resets settings to defaults
  Future<void> resetToDefaults() async {
    await _prefs.remove(_settingsKey);
  }

  /// Checks if settings exist
  bool hasSettings() {
    return _prefs.containsKey(_settingsKey);
  }
}
