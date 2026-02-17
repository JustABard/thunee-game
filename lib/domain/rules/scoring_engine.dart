import '../models/call_type.dart';
import '../models/game_config.dart';
import '../models/player.dart';
import '../models/round_state.dart';
import '../models/team.dart';
import '../models/trick.dart';
import '../../utils/constants.dart';

/// Detailed breakdown of scoring for a round
class ScoringBreakdown {
  final int team0Points;
  final int team1Points;
  final int team0BallsAwarded;
  final int team1BallsAwarded;
  final String description;
  final List<String> details;

  const ScoringBreakdown({
    required this.team0Points,
    required this.team1Points,
    required this.team0BallsAwarded,
    required this.team1BallsAwarded,
    required this.description,
    this.details = const [],
  });

  @override
  String toString() => description;
}

/// Calculates scores and awards balls for completed rounds.
/// This is a CRITICAL component with complex logic for all call types.
class ScoringEngine {
  final GameConfig config;

  ScoringEngine(this.config);

  /// Calculates the score for a completed round and returns ball adjustments.
  /// For Thunee/Royals, the round may end early (not all 6 tricks played).
  ScoringBreakdown calculateRoundScore(RoundState state) {
    // Check for special call scoring first — Thunee/Royals can end early
    final thuneeCall = state.activeThuneeCall;

    if (thuneeCall != null) {
      return _scoreThuneeRound(state, thuneeCall);
    }

    // Normal bidding round — must have all 6 tricks
    if (!state.allTricksComplete) {
      throw StateError('Cannot score incomplete round');
    }

    return _scoreNormalRound(state);
  }

  /// Scores a normal round (with bidding, no Thunee/Royals)
  ScoringBreakdown _scoreNormalRound(RoundState state) {
    // Calculate points for each team
    final team0Points = _calculateTeamPoints(state, 0);
    final team1Points = _calculateTeamPoints(state, 1);

    // Add Jodi points
    final team0JodiPoints = _calculateJodiPoints(state, 0);
    final team1JodiPoints = _calculateJodiPoints(state, 1);

    final team0Total = team0Points + team0JodiPoints;
    final team1Total = team1Points + team1JodiPoints;

    final details = <String>[];
    details.add('Team 1: $team0Points card points${team0JodiPoints > 0 ? ' + $team0JodiPoints Jodi' : ''} = $team0Total');
    details.add('Team 2: $team1Points card points${team1JodiPoints > 0 ? ' + $team1JodiPoints Jodi' : ''} = $team1Total');

    // Determine counting team
    final countingTeam = state.trumpMakingTeam;
    final nonCountingTeam = countingTeam == 0 ? 1 : 0;

    final countingTeamPoints = countingTeam == 0 ? team0Total : team1Total;
    final nonCountingTeamPoints = countingTeam == 0 ? team1Total : team0Total;

    details.add('Counting team: Team ${countingTeam + 1} (made trump)');
    details.add('Counting team points: $countingTeamPoints');

    // Check if counting team reached 105
    int team0Balls = 0;
    int team1Balls = 0;

    if (countingTeamPoints >= WINNING_THRESHOLD) {
      // Counting team wins — always +1 ball
      if (countingTeam == 0) {
        team0Balls = 1;
      } else {
        team1Balls = 1;
      }
      details.add('Counting team reached $WINNING_THRESHOLD+ → +1 ball');
    } else {
      // Counting team failed to reach threshold
      details.add('Counting team failed to reach $WINNING_THRESHOLD');

      if (config.enableCallAndLoss) {
        // Call & Loss rule: opponents get +2 balls
        if (nonCountingTeam == 0) {
          team0Balls = CALL_AND_LOSS_BALLS;
        } else {
          team1Balls = CALL_AND_LOSS_BALLS;
        }
        details.add('Call & Loss: opponents get +$CALL_AND_LOSS_BALLS balls');
      } else {
        // Standard: opponents get +1 ball
        if (nonCountingTeam == 0) {
          team0Balls = 1;
        } else {
          team1Balls = 1;
        }
        details.add('Opponents get +1 ball');
      }
    }

    // Check for Double on last trick
    final doubleCall = _getDoubleCall(state);
    if (doubleCall != null) {
      final doubleBalls = _scoreDoubleCall(state, doubleCall);
      final doubleTeam = doubleCall.caller.teamNumber;
      if (doubleTeam == 0) {
        team0Balls += doubleBalls;
      } else {
        team1Balls += doubleBalls;
      }
      details.add('Double: Team ${doubleTeam + 1} ${doubleBalls > 0 ? 'won' : 'lost'} → ${doubleBalls > 0 ? '+' : ''}$doubleBalls balls');
    }

    // Check for Kunuck on last trick
    final kunuckCall = _getKunuckCall(state);
    if (kunuckCall != null) {
      final kunuckBalls = _scoreKunuckCall(state, kunuckCall);
      final kunuckTeam = kunuckCall.caller.teamNumber;
      if (kunuckTeam == 0) {
        team0Balls += kunuckBalls;
      } else {
        team1Balls += kunuckBalls;
      }
      details.add('Kunuck: Team ${kunuckTeam + 1} ${kunuckBalls > 0 ? 'won' : 'lost'} → ${kunuckBalls > 0 ? '+' : ''}$kunuckBalls balls');
    }

    return ScoringBreakdown(
      team0Points: team0Total,
      team1Points: team1Total,
      team0BallsAwarded: team0Balls,
      team1BallsAwarded: team1Balls,
      description: 'Normal round: Team 1 +$team0Balls balls, Team 2 +$team1Balls balls',
      details: details,
    );
  }

  /// Scores a Thunee/Royals/Blind round
  ScoringBreakdown _scoreThuneeRound(RoundState state, CallData thuneeCall) {
    final callerSeat = thuneeCall.caller;
    final callerTeam = callerSeat.teamNumber;
    final opponentTeam = callerTeam == 0 ? 1 : 0;

    final details = <String>[];
    details.add('${thuneeCall.category.name} called by Team ${callerTeam + 1}');

    // Count tricks won by caller
    final callerTricks = state.completedTricks.where((t) => t.winningSeat == callerSeat).length;
    final partnerTricks = state.completedTricks.where((t) =>
        t.winningSeat?.teamNumber == callerTeam && t.winningSeat != callerSeat
    ).length;
    final opponentTricks = state.completedTricks.where((t) =>
        t.winningSeat?.teamNumber == opponentTeam
    ).length;

    details.add('Caller won $callerTricks tricks');
    details.add('Partner won $partnerTricks tricks');
    details.add('Opponents won $opponentTricks tricks');

    int team0Balls = 0;
    int team1Balls = 0;

    // Check for partner catch (partner wins any trick)
    if (partnerTricks > 0) {
      // Partner catch: opponents get +8 balls (or +4 for blind variants)
      final penaltyBalls = _getThuneePartnerCatchPenalty(thuneeCall);
      if (opponentTeam == 0) {
        team0Balls = penaltyBalls;
      } else {
        team1Balls = penaltyBalls;
      }
      details.add('PARTNER CATCH! Opponents get +$penaltyBalls balls');
    } else if (callerTricks == 6) {
      // Caller won all 6 tricks - success
      final successBalls = _getThuneeSuccessBalls(thuneeCall);
      if (callerTeam == 0) {
        team0Balls = successBalls;
      } else {
        team1Balls = successBalls;
      }
      details.add('Success! Caller\'s team gets +$successBalls balls');
    } else {
      // Opponents won at least 1 trick - failure
      // Opponents get the balls (positive); caller team gets nothing (not negative)
      final penaltyBalls = _getThuneeFailureBalls(thuneeCall).abs();
      if (opponentTeam == 0) {
        team0Balls = penaltyBalls;
      } else {
        team1Balls = penaltyBalls;
      }
      details.add('Failure! Opponents get +$penaltyBalls balls');
    }

    return ScoringBreakdown(
      team0Points: 0, // Points don't matter in Thunee rounds
      team1Points: 0,
      team0BallsAwarded: team0Balls,
      team1BallsAwarded: team1Balls,
      description: '${thuneeCall.category.name}: Team 1 ${team0Balls >= 0 ? '+' : ''}$team0Balls balls, Team 2 ${team1Balls >= 0 ? '+' : ''}$team1Balls balls',
      details: details,
    );
  }

  /// Calculates total points for a team (card points + last trick bonus)
  int _calculateTeamPoints(RoundState state, int teamNumber) {
    int points = 0;

    for (int i = 0; i < state.completedTricks.length; i++) {
      final trick = state.completedTricks[i];
      final winnerSeat = trick.winningSeat!;

      if (winnerSeat.teamNumber == teamNumber) {
        points += trick.points;

        // Add last trick bonus
        if (i == state.completedTricks.length - 1) {
          points += LAST_TRICK_BONUS;
        }
      }
    }

    return points;
  }

  /// Calculates Jodi points for a team
  int _calculateJodiPoints(RoundState state, int teamNumber) {
    int points = 0;

    for (final call in state.specialCalls) {
      if (call is JodiCall && call.caller.teamNumber == teamNumber) {
        points += call.points;
      }
    }

    return points;
  }

  /// Converts points to balls (1 ball per 10 points above 105)
  int _calculateBallsFromPoints(int points) {
    if (points < WINNING_THRESHOLD) return 0;

    final excessPoints = points - WINNING_THRESHOLD;
    return 1 + (excessPoints ~/ 10); // 1 base ball + 1 per 10 excess points
  }

  /// Gets success balls for Thunee-type calls
  int _getThuneeSuccessBalls(CallData call) {
    switch (call.category) {
      case CallCategory.thunee:
        return THUNEE_SUCCESS_BALLS;
      case CallCategory.royals:
        return ROYALS_SUCCESS_BALLS;
      case CallCategory.blindThunee:
        return config.blindThuneeSuccessBalls;
      case CallCategory.blindRoyals:
        return config.blindRoyalsSuccessBalls;
      default:
        return 0;
    }
  }

  /// Gets failure balls for Thunee-type calls (negative for caller)
  int _getThuneeFailureBalls(CallData call) {
    switch (call.category) {
      case CallCategory.thunee:
        return THUNEE_FAIL_BALLS;
      case CallCategory.royals:
        return ROYALS_FAIL_BALLS;
      case CallCategory.blindThunee:
      case CallCategory.blindRoyals:
        return BLIND_FAIL_BALLS;
      default:
        return 0;
    }
  }

  /// Gets partner catch penalty (positive value for opponents)
  int _getThuneePartnerCatchPenalty(CallData call) {
    switch (call.category) {
      case CallCategory.thunee:
        return THUNEE_PARTNER_CATCH_BALLS; // 8
      case CallCategory.royals:
        return ROYALS_PARTNER_CATCH_BALLS; // 8
      case CallCategory.blindThunee:
      case CallCategory.blindRoyals:
        return BLIND_FAIL_BALLS.abs(); // 8 (absolute value)
      default:
        return 0;
    }
  }

  /// Scores a Double call
  int _scoreDoubleCall(RoundState state, DoubleCall call) {
    final lastTrick = state.completedTricks.last;
    final callerSeat = call.caller;
    final callerTeam = callerSeat.teamNumber;

    if (lastTrick.winningSeat?.teamNumber == callerTeam) {
      return DOUBLE_SUCCESS_BALLS;
    } else {
      return DOUBLE_FAIL_BALLS;
    }
  }

  /// Scores a Kunuck call
  int _scoreKunuckCall(RoundState state, KunuckCall call) {
    final lastTrick = state.completedTricks.last;
    final callerSeat = call.caller;

    if (lastTrick.winningSeat == callerSeat) {
      return KUNUCK_SUCCESS_BALLS;
    } else {
      return KUNUCK_FAIL_BALLS;
    }
  }

  /// Gets Double call if any
  DoubleCall? _getDoubleCall(RoundState state) {
    return state.specialCalls.whereType<DoubleCall>().firstOrNull;
  }

  /// Gets Kunuck call if any
  KunuckCall? _getKunuckCall(RoundState state) {
    return state.specialCalls.whereType<KunuckCall>().firstOrNull;
  }
}

/// Extension to safely get first element or null
extension IterableExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
