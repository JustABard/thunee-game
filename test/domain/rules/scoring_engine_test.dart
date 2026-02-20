import 'package:flutter_test/flutter_test.dart';
import 'package:thunee_game/domain/models/call_type.dart';
import 'package:thunee_game/domain/models/card.dart';
import 'package:thunee_game/domain/models/game_config.dart';
import 'package:thunee_game/domain/models/player.dart';
import 'package:thunee_game/domain/models/rank.dart';
import 'package:thunee_game/domain/models/round_state.dart';
import 'package:thunee_game/domain/models/suit.dart';
import 'package:thunee_game/domain/models/team.dart';
import 'package:thunee_game/domain/models/trick.dart';
import 'package:thunee_game/domain/rules/scoring_engine.dart';
import 'package:thunee_game/utils/constants.dart';

void main() {
  late ScoringEngine engine;
  late GameConfig config;
  late List<Player> players;
  late List<Team> teams;

  setUp(() {
    config = const GameConfig();
    engine = ScoringEngine(config);

    players = [
      Player(id: '1', name: 'South', seat: Seat.south, hand: [], isBot: false),
      Player(id: '2', name: 'West', seat: Seat.west, hand: [], isBot: false),
      Player(id: '3', name: 'North', seat: Seat.north, hand: [], isBot: false),
      Player(id: '4', name: 'East', seat: Seat.east, hand: [], isBot: false),
    ];

    teams = [
      const Team(teamNumber: 0, name: 'Team 1'),
      const Team(teamNumber: 1, name: 'Team 2'),
    ];
  });

  group('ScoringEngine - Normal Rounds', () {
    test('counting team wins with 105+ points gets 1 ball', () {
      // Team 0 is counting team (opponents of trump maker team 1)
      // Use helper to give team 0 exactly 105 points
      final tricks = _createTricksWithPoints(team0Points: 105, team1Points: 0);

      final state = RoundState(
        phase: RoundPhase.scoring,
        players: players,
        teams: teams,
        completedTricks: tricks,
        trumpMakingTeam: 1, // Team 1 made trump, so team 0 is counting team
        currentTurn: Seat.south,
      );

      final score = engine.calculateRoundScore(state);

      // Counting team (team 0) reached 105 → team 0 gets 1 ball
      expect(score.team0BallsAwarded, equals(1));
      expect(score.team1BallsAwarded, equals(0));
    });

    test('counting team with 115 points still gets 1 ball (no excess-point bonus)', () {
      // Team 0 is counting team (opponents of trump maker team 1)
      final tricks = _createTricksWithPoints(team0Points: 115, team1Points: 0);

      final state = RoundState(
        phase: RoundPhase.scoring,
        players: players,
        teams: teams,
        completedTricks: tricks,
        trumpMakingTeam: 1, // Team 1 made trump, team 0 is counting
        currentTurn: Seat.south,
      );

      final score = engine.calculateRoundScore(state);

      // Standard scoring: counting team reaches threshold → 1 ball
      expect(score.team0BallsAwarded, equals(1));
      expect(score.team1BallsAwarded, equals(0));
    });

    test('counting team fails to reach 105, trump maker gets 1 ball (no Call & Loss)', () {
      final engineNoCallLoss = ScoringEngine(
        const GameConfig(enableCallAndLoss: false),
      );

      // Team 0 is counting team (opponents of trump maker team 1)
      // Team 0 has only 100 pts < 105, counting team fails
      final tricks = _createTricksWithPoints(team0Points: 100, team1Points: 5);

      final state = RoundState(
        phase: RoundPhase.scoring,
        players: players,
        teams: teams,
        completedTricks: tricks,
        trumpMakingTeam: 1, // Team 1 made trump
        currentTurn: Seat.south,
      );

      final score = engineNoCallLoss.calculateRoundScore(state);

      // Counting team (team 0) failed → trump maker (team 1) gets 1 ball
      expect(score.team0BallsAwarded, equals(0));
      expect(score.team1BallsAwarded, equals(1));
    });

    test('Call & Loss rule: counting team fails, trump maker gets 2 balls', () {
      final engineWithCallLoss = ScoringEngine(
        const GameConfig(enableCallAndLoss: true),
      );

      // Team 0 is counting team (opponents of trump maker team 1)
      final tricks = _createTricksWithPoints(team0Points: 100, team1Points: 5);

      final state = RoundState(
        phase: RoundPhase.scoring,
        players: players,
        teams: teams,
        completedTricks: tricks,
        trumpMakingTeam: 1, // Team 1 made trump
        currentTurn: Seat.south,
      );

      final score = engineWithCallLoss.calculateRoundScore(state);

      // Counting team (team 0) failed → trump maker (team 1) gets 2 balls (Call & Loss)
      expect(score.team0BallsAwarded, equals(0));
      expect(score.team1BallsAwarded, equals(2));
    });
  });

  group('ScoringEngine - Thunee', () {
    test('Thunee success: caller wins all 6 tricks, gets +4 balls', () {
      final tricks = List.generate(
        6,
        (_) => Trick.empty(Seat.south)
            .playCard(Seat.south, Card(suit: Suit.hearts, rank: Rank.jack))
            .playCard(Seat.west, Card(suit: Suit.hearts, rank: Rank.nine))
            .playCard(Seat.north, Card(suit: Suit.hearts, rank: Rank.ace))
            .playCard(Seat.east, Card(suit: Suit.hearts, rank: Rank.ten))
            .withWinner(Seat.south), // Caller wins
      );

      final state = RoundState(
        phase: RoundPhase.scoring,
        players: players,
        teams: teams,
        completedTricks: tricks,
        trumpMakingTeam: 0,
        currentTurn: Seat.south,
        callHistory: [
          const ThuneeCall(caller: Seat.south, trumpSuit: Suit.hearts),
        ],
      );

      final score = engine.calculateRoundScore(state);

      expect(score.team0BallsAwarded, equals(4)); // Success
      expect(score.team1BallsAwarded, equals(0));
    });

    test('Thunee failure: opponent wins 1 trick, opponents get +4 balls', () {
      final tricks = [
        ...List.generate(
          5,
          (_) => Trick.empty(Seat.south)
              .playCard(Seat.south, Card(suit: Suit.hearts, rank: Rank.jack))
              .playCard(Seat.west, Card(suit: Suit.hearts, rank: Rank.nine))
              .playCard(Seat.north, Card(suit: Suit.hearts, rank: Rank.ace))
              .playCard(Seat.east, Card(suit: Suit.hearts, rank: Rank.ten))
              .withWinner(Seat.south), // Caller wins
        ),
        Trick.empty(Seat.south)
            .playCard(Seat.south, Card(suit: Suit.hearts, rank: Rank.queen))
            .playCard(Seat.west, Card(suit: Suit.hearts, rank: Rank.king))
            .playCard(Seat.north, Card(suit: Suit.hearts, rank: Rank.ten))
            .playCard(Seat.east, Card(suit: Suit.hearts, rank: Rank.ace))
            .withWinner(Seat.west), // Opponent wins
      ];

      final state = RoundState(
        phase: RoundPhase.scoring,
        players: players,
        teams: teams,
        completedTricks: tricks,
        trumpMakingTeam: 0,
        currentTurn: Seat.south,
        callHistory: [
          const ThuneeCall(caller: Seat.south, trumpSuit: Suit.hearts),
        ],
      );

      final score = engine.calculateRoundScore(state);

      expect(score.team0BallsAwarded, equals(0)); // Caller team gets 0 (no negative)
      expect(score.team1BallsAwarded, equals(4)); // Opponents get +4
    });

    test('Partner catch: partner wins any trick, opponents get +8 balls', () {
      final tricks = [
        ...List.generate(
          5,
          (_) => Trick.empty(Seat.south)
              .playCard(Seat.south, Card(suit: Suit.hearts, rank: Rank.jack))
              .playCard(Seat.west, Card(suit: Suit.hearts, rank: Rank.nine))
              .playCard(Seat.north, Card(suit: Suit.hearts, rank: Rank.ace))
              .playCard(Seat.east, Card(suit: Suit.hearts, rank: Rank.ten))
              .withWinner(Seat.south), // Caller wins
        ),
        Trick.empty(Seat.south)
            .playCard(Seat.south, Card(suit: Suit.hearts, rank: Rank.queen))
            .playCard(Seat.west, Card(suit: Suit.hearts, rank: Rank.king))
            .playCard(Seat.north, Card(suit: Suit.hearts, rank: Rank.jack)) // Partner
            .playCard(Seat.east, Card(suit: Suit.hearts, rank: Rank.ace))
            .withWinner(Seat.north), // PARTNER CATCH!
      ];

      final state = RoundState(
        phase: RoundPhase.scoring,
        players: players,
        teams: teams,
        completedTricks: tricks,
        trumpMakingTeam: 0,
        currentTurn: Seat.south,
        callHistory: [
          const ThuneeCall(caller: Seat.south, trumpSuit: Suit.hearts),
        ],
      );

      final score = engine.calculateRoundScore(state);

      expect(score.team1BallsAwarded, equals(8)); // Opponents get +8 for partner catch
    });
  });

  group('ScoringEngine - Special Calls', () {
    test('Jodi (K+Q non-trump) adds 20 points', () {
      final tricks = _createTricksWithPoints(team0Points: 105, team1Points: 0);

      final state = RoundState(
        phase: RoundPhase.scoring,
        players: players,
        teams: teams,
        completedTricks: tricks,
        trumpMakingTeam: 0,
        trumpSuit: Suit.hearts, // Hearts is trump
        currentTurn: Seat.south,
        callHistory: [
          JodiCall(
            caller: Seat.south,
            cards: [
              Card(suit: Suit.spades, rank: Rank.king),
              Card(suit: Suit.spades, rank: Rank.queen),
            ],
            isTrump: false, // Spades, not trump
          ),
        ],
      );

      final score = engine.calculateRoundScore(state);

      expect(score.team0Points, equals(125)); // 105 + 20 Jodi
    });

    test('Jodi (K+Q trump) adds 40 points', () {
      final tricks = _createTricksWithPoints(team0Points: 105, team1Points: 0);

      final state = RoundState(
        phase: RoundPhase.scoring,
        players: players,
        teams: teams,
        completedTricks: tricks,
        trumpMakingTeam: 0,
        trumpSuit: Suit.hearts,
        currentTurn: Seat.south,
        callHistory: [
          JodiCall(
            caller: Seat.south,
            cards: [
              Card(suit: Suit.hearts, rank: Rank.king),
              Card(suit: Suit.hearts, rank: Rank.queen),
            ],
            isTrump: true, // Hearts is trump
          ),
        ],
      );

      final score = engine.calculateRoundScore(state);

      expect(score.team0Points, equals(145)); // 105 + 40 Jodi
    });
  });
}

// Helper to create tricks with specific winners and card combinations
List<Trick> _createTricksWithPoints({required int team0Points, required int team1Points}) {
  final tricks = <Trick>[];

  // Distribute points across tricks
  // Team 0 cards to use: J=30, 9=20, A=11, 10=10
  // Calculate how many tricks each team should win

  // Simplified: Create 6 tricks with specific point distributions
  // Team 0 wins tricks to get team0Points
  // Team 1 wins tricks to get team1Points

  final cardsUsed = <Card>[];
  int team0Accumulated = 0;
  int team1Accumulated = 0;

  for (int i = 0; i < 6; i++) {
    final isLastTrick = i == 5;

    // Determine winner and points for this trick
    Seat winner;
    int basePoints;

    if (team0Accumulated < team0Points) {
      winner = Seat.south; // Team 0
      basePoints = (team0Points - team0Accumulated).clamp(0, 76);
      team0Accumulated += basePoints;
      if (isLastTrick) team0Accumulated += LAST_TRICK_BONUS;
    } else {
      winner = Seat.west; // Team 1
      basePoints = (team1Points - team1Accumulated).clamp(0, 76);
      team1Accumulated += basePoints;
      if (isLastTrick) team1Accumulated += LAST_TRICK_BONUS;
    }

    final trick = Trick(
      cardsPlayed: {
        Seat.south: Card(suit: Suit.hearts, rank: Rank.jack),
        Seat.west: Card(suit: Suit.spades, rank: Rank.nine),
        Seat.north: Card(suit: Suit.diamonds, rank: Rank.ace),
        Seat.east: Card(suit: Suit.clubs, rank: Rank.ten),
      },
      leadSeat: Seat.south,
      leadSuit: Suit.hearts,
      winningSeat: winner,
      points: basePoints,
    );

    tricks.add(trick);
  }

  return tricks;
}
