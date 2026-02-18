import 'package:equatable/equatable.dart';
import 'game_config.dart';
import 'team.dart';
import 'player.dart';
import 'round_state.dart';

/// Represents the state of a complete match (multiple rounds to 12/13 balls)
class MatchState extends Equatable {
  final GameConfig config;
  final List<Player> players; // All 4 players
  final List<Team> teams; // Both teams with balls
  final List<RoundState> completedRounds;
  final RoundState? currentRound;
  final bool isComplete;
  final int? winningTeam; // Team number that won (0 or 1)

  const MatchState({
    required this.config,
    required this.players,
    required this.teams,
    this.completedRounds = const [],
    this.currentRound,
    this.isComplete = false,
    this.winningTeam,
  });

  /// Creates a new match
  factory MatchState.newMatch({
    required GameConfig config,
    required List<Player> players,
  }) {
    // Create teams
    final teams = [
      Team(
        teamNumber: 0,
        name: 'Team 1', // South + North
      ),
      Team(
        teamNumber: 1,
        name: 'Team 2', // West + East
      ),
    ];

    return MatchState(
      config: config,
      players: players,
      teams: teams,
    );
  }

  /// Returns the current match target (12 or 13 if Kunuck played)
  int get matchTarget => config.matchTarget;

  /// Returns true if any team has reached the target balls
  bool hasWinner() {
    return teams.any((team) => team.balls >= matchTarget);
  }

  /// Returns the winning team if match is complete, null otherwise
  Team? get winner {
    if (!isComplete || winningTeam == null) return null;
    return teams[winningTeam!];
  }

  /// Returns the number of rounds played (completed + current)
  int get roundsPlayed {
    return completedRounds.length + (currentRound != null ? 1 : 0);
  }

  /// Creates a copy with updated fields
  MatchState copyWith({
    GameConfig? config,
    List<Player>? players,
    List<Team>? teams,
    List<RoundState>? completedRounds,
    RoundState? currentRound,
    bool? isComplete,
    int? winningTeam,
  }) {
    return MatchState(
      config: config ?? this.config,
      players: players ?? this.players,
      teams: teams ?? this.teams,
      completedRounds: completedRounds ?? this.completedRounds,
      currentRound: currentRound ?? this.currentRound,
      isComplete: isComplete ?? this.isComplete,
      winningTeam: winningTeam ?? this.winningTeam,
    );
  }

  /// Updates a specific team
  MatchState updateTeam(Team updatedTeam) {
    final updatedTeams = teams.map((t) {
      return t.teamNumber == updatedTeam.teamNumber ? updatedTeam : t;
    }).toList();

    return copyWith(teams: updatedTeams);
  }

  /// Adds balls to a team
  MatchState addBallsToTeam(int teamNumber, int balls) {
    final team = teams[teamNumber];
    final updatedTeam = team.addBalls(balls);
    return updateTeam(updatedTeam);
  }

  /// Starts a new round
  MatchState startNewRound(RoundState round) {
    return copyWith(currentRound: round);
  }

  /// Completes the current round and adds it to history
  MatchState completeCurrentRound() {
    if (currentRound == null) {
      throw StateError('No current round to complete');
    }

    final updatedCompletedRounds = [...completedRounds, currentRound!];

    // Check if match is complete
    final matchComplete = hasWinner();
    final winner = matchComplete
        ? teams.indexWhere((team) => team.balls >= matchTarget)
        : null;

    // Construct directly to explicitly set currentRound to null
    // (copyWith cannot clear currentRound since it uses ??)
    return MatchState(
      config: config,
      players: players,
      teams: teams,
      completedRounds: updatedCompletedRounds,
      currentRound: null,
      isComplete: matchComplete,
      winningTeam: winner,
    );
  }

  /// Serializes to JSON map
  Map<String, dynamic> toJson() => {
        'config': config.toJson(),
        'players': players.map((p) => p.toJson()).toList(),
        'teams': teams.map((t) => t.toJson()).toList(),
        'completedRounds':
            completedRounds.map((r) => r.toJson()).toList(),
        'currentRound': currentRound?.toJson(),
        'isComplete': isComplete,
        'winningTeam': winningTeam,
      };

  /// Deserializes from JSON map
  factory MatchState.fromJson(Map<String, dynamic> json) => MatchState(
        config:
            GameConfig.fromJson(json['config'] as Map<String, dynamic>),
        players: (json['players'] as List)
            .map((p) => Player.fromJson(p as Map<String, dynamic>))
            .toList(),
        teams: (json['teams'] as List)
            .map((t) => Team.fromJson(t as Map<String, dynamic>))
            .toList(),
        completedRounds: (json['completedRounds'] as List?)
                ?.map((r) =>
                    RoundState.fromJson(r as Map<String, dynamic>))
                .toList() ??
            [],
        currentRound: json['currentRound'] != null
            ? RoundState.fromJson(
                json['currentRound'] as Map<String, dynamic>)
            : null,
        isComplete: json['isComplete'] as bool? ?? false,
        winningTeam: json['winningTeam'] as int?,
      );

  @override
  List<Object?> get props => [
        config,
        players,
        teams,
        completedRounds,
        currentRound,
        isComplete,
        winningTeam,
      ];

  @override
  String toString() => 'MatchState('
      'Rounds: $roundsPlayed, '
      'Team 1: ${teams[0].balls} balls, '
      'Team 2: ${teams[1].balls} balls, '
      'Target: $matchTarget, '
      'Complete: $isComplete)';
}
