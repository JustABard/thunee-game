import '../../domain/models/game_config.dart';

/// Data Transfer Object for persisting GameConfig settings
class SettingsDto {
  final bool enableRoyals;
  final bool enableBlindThunee;
  final bool enableBlindRoyals;
  final bool enableKunuck;
  final bool enableFirstThirdOnlyJodiCalls;
  final bool enableCallOverTeammates;
  final bool enableCallAndLoss;
  final int blindThuneeSuccessBalls;
  final int blindRoyalsSuccessBalls;
  final int matchTarget;

  const SettingsDto({
    required this.enableRoyals,
    required this.enableBlindThunee,
    required this.enableBlindRoyals,
    required this.enableKunuck,
    required this.enableFirstThirdOnlyJodiCalls,
    required this.enableCallOverTeammates,
    required this.enableCallAndLoss,
    required this.blindThuneeSuccessBalls,
    required this.blindRoyalsSuccessBalls,
    required this.matchTarget,
  });

  /// Creates DTO from GameConfig
  factory SettingsDto.fromConfig(GameConfig config) {
    return SettingsDto(
      enableRoyals: config.enableRoyals,
      enableBlindThunee: config.enableBlindThunee,
      enableBlindRoyals: config.enableBlindRoyals,
      enableKunuck: config.enableKunuck,
      enableFirstThirdOnlyJodiCalls: config.enableFirstThirdOnlyJodiCalls,
      enableCallOverTeammates: config.enableCallOverTeammates,
      enableCallAndLoss: config.enableCallAndLoss,
      blindThuneeSuccessBalls: config.blindThuneeSuccessBalls,
      blindRoyalsSuccessBalls: config.blindRoyalsSuccessBalls,
      matchTarget: config.matchTarget,
    );
  }

  /// Converts to GameConfig
  GameConfig toConfig() {
    return GameConfig(
      enableRoyals: enableRoyals,
      enableBlindThunee: enableBlindThunee,
      enableBlindRoyals: enableBlindRoyals,
      enableKunuck: enableKunuck,
      enableFirstThirdOnlyJodiCalls: enableFirstThirdOnlyJodiCalls,
      enableCallOverTeammates: enableCallOverTeammates,
      enableCallAndLoss: enableCallAndLoss,
      blindThuneeSuccessBalls: blindThuneeSuccessBalls,
      blindRoyalsSuccessBalls: blindRoyalsSuccessBalls,
      matchTarget: matchTarget,
    );
  }

  /// Converts to JSON map
  Map<String, dynamic> toJson() {
    return {
      'enableRoyals': enableRoyals,
      'enableBlindThunee': enableBlindThunee,
      'enableBlindRoyals': enableBlindRoyals,
      'enableKunuck': enableKunuck,
      'enableFirstThirdOnlyJodiCalls': enableFirstThirdOnlyJodiCalls,
      'enableCallOverTeammates': enableCallOverTeammates,
      'enableCallAndLoss': enableCallAndLoss,
      'blindThuneeSuccessBalls': blindThuneeSuccessBalls,
      'blindRoyalsSuccessBalls': blindRoyalsSuccessBalls,
      'matchTarget': matchTarget,
    };
  }

  /// Creates DTO from JSON map
  factory SettingsDto.fromJson(Map<String, dynamic> json) {
    return SettingsDto(
      enableRoyals: json['enableRoyals'] as bool? ?? true,
      enableBlindThunee: json['enableBlindThunee'] as bool? ?? true,
      enableBlindRoyals: json['enableBlindRoyals'] as bool? ?? true,
      enableKunuck: json['enableKunuck'] as bool? ?? true,
      enableFirstThirdOnlyJodiCalls: json['enableFirstThirdOnlyJodiCalls'] as bool? ?? true,
      enableCallOverTeammates: json['enableCallOverTeammates'] as bool? ?? false,
      enableCallAndLoss: json['enableCallAndLoss'] as bool? ?? false,
      blindThuneeSuccessBalls: json['blindThuneeSuccessBalls'] as int? ?? 8,
      blindRoyalsSuccessBalls: json['blindRoyalsSuccessBalls'] as int? ?? 8,
      matchTarget: json['matchTarget'] as int? ?? 12,
    );
  }

  /// Default settings (all features enabled)
  factory SettingsDto.defaults() {
    return SettingsDto(
      enableRoyals: true,
      enableBlindThunee: true,
      enableBlindRoyals: true,
      enableKunuck: true,
      enableFirstThirdOnlyJodiCalls: true,
      enableCallOverTeammates: false,
      enableCallAndLoss: false,
      blindThuneeSuccessBalls: 8,
      blindRoyalsSuccessBalls: 8,
      matchTarget: 12,
    );
  }
}
