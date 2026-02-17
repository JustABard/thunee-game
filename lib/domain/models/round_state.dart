import 'package:equatable/equatable.dart';
import 'player.dart';
import 'team.dart';
import 'trick.dart';
import 'call_type.dart';
import 'card.dart';
import 'suit.dart';

/// Represents the phase of a round
enum RoundPhase {
  dealing,       // Cards being dealt
  bidding,       // Players are bidding
  choosingTrump, // Bid winner selects trump card (card stays in hand, suit becomes trump)
  playing,       // Tricks being played
  scoring,       // Round finished, calculating scores
}

/// Represents the complete state of a single round
class RoundState extends Equatable {
  final RoundPhase phase;
  final List<Player> players; // All 4 players with their hands
  final List<Team> teams; // Both teams
  final List<Trick> completedTricks; // Tricks that have been won
  final Trick? currentTrick; // Trick in progress
  final List<CallData> callHistory; // All calls made (bids, passes, special calls)
  final BidCall? highestBid; // Current highest bid
  final int passCount; // Number of consecutive passes
  final Suit? trumpSuit; // Trump suit for this round (from bid winner or first card)
  final Card? trumpCard; // The actual card tapped to set trump (null if set by first lead)
  final int trumpMakingTeam; // Team that made trump (0 or 1)
  final Seat currentTurn; // Whose turn it is
  final Seat dealer; // Who dealt this round
  /// The 2 cards per player held back until bidding completes.
  /// Non-null during [RoundPhase.bidding], cleared to null when playing begins.
  final List<List<Card>>? remainingCards;

  const RoundState({
    required this.phase,
    required this.players,
    required this.teams,
    this.completedTricks = const [],
    this.currentTrick,
    this.callHistory = const [],
    this.highestBid,
    this.passCount = 0,
    this.trumpSuit,
    this.trumpCard,
    this.trumpMakingTeam = 0,
    required this.currentTurn,
    this.dealer = Seat.south,
    this.remainingCards,
  });

  /// Creates initial round state for dealing
  factory RoundState.initial({
    required List<Player> players,
    required List<Team> teams,
    required Seat dealer,
  }) {
    return RoundState(
      phase: RoundPhase.dealing,
      players: players,
      teams: teams,
      dealer: dealer,
      currentTurn: dealer.next, // First to bid is right of dealer (anti-clockwise)
    );
  }

  /// Returns the current player (whose turn it is)
  Player get currentPlayer {
    return players.firstWhere((p) => p.seat == currentTurn);
  }

  /// Returns a player by seat
  Player playerAt(Seat seat) {
    return players.firstWhere((p) => p.seat == seat);
  }

  /// Returns the team for a seat
  Team teamFor(Seat seat) {
    final teamNumber = seat.teamNumber;
    return teams[teamNumber];
  }

  /// Returns the team that is currently counting (has made trump)
  Team get countingTeam => teams[trumpMakingTeam];

  /// Returns the non-counting team
  Team get nonCountingTeam => teams[trumpMakingTeam == 0 ? 1 : 0];

  /// Returns all active special calls (non-bid/pass)
  List<CallData> get specialCalls {
    return callHistory.where((call) =>
        call.category != CallCategory.bid &&
        call.category != CallCategory.pass
    ).toList();
  }

  /// Returns the active Thunee-like call if any (Thunee, Royals, BlindThunee, BlindRoyals)
  CallData? get activeThuneeCall {
    try {
      return specialCalls.reversed.firstWhere(
        (call) =>
            call.category == CallCategory.thunee ||
            call.category == CallCategory.royals ||
            call.category == CallCategory.blindThunee ||
            call.category == CallCategory.blindRoyals,
      );
    } catch (e) {
      return null;
    }
  }

  /// Returns true if Royals mode is active
  bool get isRoyalsMode {
    final thuneeCall = activeThuneeCall;
    return thuneeCall != null &&
        (thuneeCall.category == CallCategory.royals ||
         thuneeCall.category == CallCategory.blindRoyals);
  }

  /// Returns the number of tricks completed
  int get tricksCompleted => completedTricks.length;

  /// Returns true if all 6 tricks are complete
  bool get allTricksComplete => tricksCompleted == 6;

  /// Returns the last completed trick, or null if none
  Trick? get lastCompletedTrick {
    return completedTricks.isEmpty ? null : completedTricks.last;
  }

  /// Creates a copy with updated fields.
  /// Note: [remainingCards] is preserved from the current state unless explicitly
  /// provided. To clear it, use [distributeRemainingCards] instead.
  RoundState copyWith({
    RoundPhase? phase,
    List<Player>? players,
    List<Team>? teams,
    List<Trick>? completedTricks,
    Trick? currentTrick,
    List<CallData>? callHistory,
    BidCall? highestBid,
    int? passCount,
    Suit? trumpSuit,
    Card? trumpCard,
    int? trumpMakingTeam,
    Seat? currentTurn,
    Seat? dealer,
    List<List<Card>>? remainingCards,
  }) {
    return RoundState(
      phase: phase ?? this.phase,
      players: players ?? this.players,
      teams: teams ?? this.teams,
      completedTricks: completedTricks ?? this.completedTricks,
      currentTrick: currentTrick ?? this.currentTrick,
      callHistory: callHistory ?? this.callHistory,
      highestBid: highestBid ?? this.highestBid,
      passCount: passCount ?? this.passCount,
      trumpSuit: trumpSuit ?? this.trumpSuit,
      trumpCard: trumpCard ?? this.trumpCard,
      trumpMakingTeam: trumpMakingTeam ?? this.trumpMakingTeam,
      currentTurn: currentTurn ?? this.currentTurn,
      dealer: dealer ?? this.dealer,
      remainingCards: remainingCards ?? this.remainingCards,
    );
  }

  /// Distributes the held-back 2 cards to each player and clears [remainingCards].
  /// Returns a new state with players holding all 6 cards and [remainingCards] null.
  RoundState distributeRemainingCards() {
    if (remainingCards == null) return this;

    final updatedPlayers = players.asMap().entries.map((entry) {
      final index = entry.key;
      final player = entry.value;
      final extra = remainingCards![index];
      return player.copyWith(hand: [...player.hand, ...extra]);
    }).toList();

    return RoundState(
      phase: phase,
      players: updatedPlayers,
      teams: teams,
      completedTricks: completedTricks,
      currentTrick: currentTrick,
      callHistory: callHistory,
      highestBid: highestBid,
      passCount: passCount,
      trumpSuit: trumpSuit,
      trumpCard: trumpCard,
      trumpMakingTeam: trumpMakingTeam,
      currentTurn: currentTurn,
      dealer: dealer,
      remainingCards: null, // explicitly cleared
    );
  }

  /// Updates a specific player in the players list
  RoundState updatePlayer(Player updatedPlayer) {
    final updatedPlayers = players.map((p) {
      return p.seat == updatedPlayer.seat ? updatedPlayer : p;
    }).toList();

    return copyWith(players: updatedPlayers);
  }

  /// Updates a specific team
  RoundState updateTeam(Team updatedTeam) {
    final updatedTeams = teams.map((t) {
      return t.teamNumber == updatedTeam.teamNumber ? updatedTeam : t;
    }).toList();

    return copyWith(teams: updatedTeams);
  }

  @override
  List<Object?> get props => [
        phase,
        players,
        teams,
        completedTricks,
        currentTrick,
        callHistory,
        highestBid,
        passCount,
        trumpSuit,
        trumpCard,
        trumpMakingTeam,
        currentTurn,
        dealer,
        remainingCards,
      ];

  @override
  String toString() => 'RoundState('
      'phase: $phase, '
      'turn: $currentTurn, '
      'tricks: $tricksCompleted/6, '
      'trump: $trumpSuit)';
}
