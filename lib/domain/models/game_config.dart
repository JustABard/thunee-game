import 'package:equatable/equatable.dart';
import '../../utils/constants.dart';

/// Configuration for a Thunee match, including all house rules
class GameConfig extends Equatable {
  // Special call toggles
  final bool enableRoyals;
  final bool enableBlindThunee;
  final bool enableBlindRoyals;
  final bool enableJodi;
  final bool enableDouble;
  final bool enableKunuck;

  // House rules
  final bool enableFirstThirdOnlyJodiCalls; // Jodi only on tricks 1 or 3
  final bool enableCallOverTeammates; // Can bid over partner's call
  final bool enableCallAndLoss; // Trump-making team loses → opponents get +2 balls

  // Configurable ball values
  final int blindThuneeSuccessBalls; // Default 8, configurable 4-10
  final int blindRoyalsSuccessBalls; // Default 8, configurable 4-10

  // Match settings
  final int matchTarget; // Default 12, or 13 if Kunuck played

  const GameConfig({
    this.enableRoyals = true,
    this.enableBlindThunee = true,
    this.enableBlindRoyals = true,
    this.enableJodi = true,
    this.enableDouble = true,
    this.enableKunuck = true,
    this.enableFirstThirdOnlyJodiCalls = false,
    this.enableCallOverTeammates = false,
    this.enableCallAndLoss = false,
    this.blindThuneeSuccessBalls = DEFAULT_BLIND_THUNEE_SUCCESS_BALLS,
    this.blindRoyalsSuccessBalls = DEFAULT_BLIND_ROYALS_SUCCESS_BALLS,
    this.matchTarget = DEFAULT_MATCH_TARGET,
  });

  /// Creates a copy with updated fields
  GameConfig copyWith({
    bool? enableRoyals,
    bool? enableBlindThunee,
    bool? enableBlindRoyals,
    bool? enableJodi,
    bool? enableDouble,
    bool? enableKunuck,
    bool? enableFirstThirdOnlyJodiCalls,
    bool? enableCallOverTeammates,
    bool? enableCallAndLoss,
    int? blindThuneeSuccessBalls,
    int? blindRoyalsSuccessBalls,
    int? matchTarget,
  }) {
    return GameConfig(
      enableRoyals: enableRoyals ?? this.enableRoyals,
      enableBlindThunee: enableBlindThunee ?? this.enableBlindThunee,
      enableBlindRoyals: enableBlindRoyals ?? this.enableBlindRoyals,
      enableJodi: enableJodi ?? this.enableJodi,
      enableDouble: enableDouble ?? this.enableDouble,
      enableKunuck: enableKunuck ?? this.enableKunuck,
      enableFirstThirdOnlyJodiCalls:
          enableFirstThirdOnlyJodiCalls ?? this.enableFirstThirdOnlyJodiCalls,
      enableCallOverTeammates:
          enableCallOverTeammates ?? this.enableCallOverTeammates,
      enableCallAndLoss: enableCallAndLoss ?? this.enableCallAndLoss,
      blindThuneeSuccessBalls:
          blindThuneeSuccessBalls ?? this.blindThuneeSuccessBalls,
      blindRoyalsSuccessBalls:
          blindRoyalsSuccessBalls ?? this.blindRoyalsSuccessBalls,
      matchTarget: matchTarget ?? this.matchTarget,
    );
  }

  /// Default configuration with all features enabled
  factory GameConfig.standard() => const GameConfig();

  /// Configuration with no special calls (basic game only)
  factory GameConfig.basic() {
    return const GameConfig(
      enableRoyals: false,
      enableBlindThunee: false,
      enableBlindRoyals: false,
      enableJodi: false,
      enableDouble: false,
      enableKunuck: false,
    );
  }

  /// Configuration with strict house rules
  factory GameConfig.strict() {
    return const GameConfig(
      enableFirstThirdOnlyJodiCalls: true,
      enableCallOverTeammates: false,
      enableCallAndLoss: true,
    );
  }

  /// Serializes to JSON map
  Map<String, dynamic> toJson() => {
        'enableRoyals': enableRoyals,
        'enableBlindThunee': enableBlindThunee,
        'enableBlindRoyals': enableBlindRoyals,
        'enableJodi': enableJodi,
        'enableDouble': enableDouble,
        'enableKunuck': enableKunuck,
        'enableFirstThirdOnlyJodiCalls': enableFirstThirdOnlyJodiCalls,
        'enableCallOverTeammates': enableCallOverTeammates,
        'enableCallAndLoss': enableCallAndLoss,
        'blindThuneeSuccessBalls': blindThuneeSuccessBalls,
        'blindRoyalsSuccessBalls': blindRoyalsSuccessBalls,
        'matchTarget': matchTarget,
      };

  /// Deserializes from JSON map
  factory GameConfig.fromJson(Map<String, dynamic> json) => GameConfig(
        enableRoyals: json['enableRoyals'] as bool? ?? true,
        enableBlindThunee: json['enableBlindThunee'] as bool? ?? true,
        enableBlindRoyals: json['enableBlindRoyals'] as bool? ?? true,
        enableJodi: json['enableJodi'] as bool? ?? true,
        enableDouble: json['enableDouble'] as bool? ?? true,
        enableKunuck: json['enableKunuck'] as bool? ?? true,
        enableFirstThirdOnlyJodiCalls:
            json['enableFirstThirdOnlyJodiCalls'] as bool? ?? false,
        enableCallOverTeammates:
            json['enableCallOverTeammates'] as bool? ?? false,
        enableCallAndLoss: json['enableCallAndLoss'] as bool? ?? false,
        blindThuneeSuccessBalls:
            json['blindThuneeSuccessBalls'] as int? ?? 8,
        blindRoyalsSuccessBalls:
            json['blindRoyalsSuccessBalls'] as int? ?? 8,
        matchTarget: json['matchTarget'] as int? ?? 12,
      );

  @override
  List<Object?> get props => [
        enableRoyals,
        enableBlindThunee,
        enableBlindRoyals,
        enableJodi,
        enableDouble,
        enableKunuck,
        enableFirstThirdOnlyJodiCalls,
        enableCallOverTeammates,
        enableCallAndLoss,
        blindThuneeSuccessBalls,
        blindRoyalsSuccessBalls,
        matchTarget,
      ];

  @override
  String toString() => 'GameConfig('
      'Royals: $enableRoyals, '
      'BlindThunee: $enableBlindThunee, '
      'BlindRoyals: $enableBlindRoyals, '
      'Jodi: $enableJodi, '
      'Double: $enableDouble, '
      'Kunuck: $enableKunuck, '
      'Target: $matchTarget balls)';
}
