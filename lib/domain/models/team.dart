import 'package:equatable/equatable.dart';

/// Represents a team in the game (partnership of 2 players)
class Team extends Equatable {
  final int teamNumber; // 0 or 1
  final String name;
  final int tricksWon;
  final int pointsCollected;
  final int balls; // Match-level score

  const Team({
    required this.teamNumber,
    required this.name,
    this.tricksWon = 0,
    this.pointsCollected = 0,
    this.balls = 0,
  });

  /// Creates a copy with updated fields
  Team copyWith({
    int? teamNumber,
    String? name,
    int? tricksWon,
    int? pointsCollected,
    int? balls,
  }) {
    return Team(
      teamNumber: teamNumber ?? this.teamNumber,
      name: name ?? this.name,
      tricksWon: tricksWon ?? this.tricksWon,
      pointsCollected: pointsCollected ?? this.pointsCollected,
      balls: balls ?? this.balls,
    );
  }

  /// Adds a trick to this team
  Team addTrick(int points) {
    return copyWith(
      tricksWon: tricksWon + 1,
      pointsCollected: pointsCollected + points,
    );
  }

  /// Adds balls to this team
  Team addBalls(int ballsToAdd) {
    return copyWith(balls: balls + ballsToAdd);
  }

  /// Resets round-specific stats (tricks and points) for a new round
  Team resetRound() {
    return copyWith(
      tricksWon: 0,
      pointsCollected: 0,
    );
  }

  @override
  List<Object?> get props => [teamNumber, name, tricksWon, pointsCollected, balls];

  @override
  String toString() =>
      'Team $teamNumber: $name (Tricks: $tricksWon, Points: $pointsCollected, Balls: $balls)';
}
