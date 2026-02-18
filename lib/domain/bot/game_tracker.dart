import '../models/card.dart';
import '../models/player.dart';
import '../models/rank.dart';
import '../models/suit.dart';
import '../models/trick.dart';

/// Tracks played cards and derives information about the game state.
///
/// All data is derived from completed tricks and the current trick only —
/// never reads other players' hands.
class GameTracker {
  /// All cards that have appeared in completed or current tricks.
  final Set<Card> playedCards;

  /// Seats known to be void in a suit (failed to follow when that suit was led).
  final Map<Seat, Set<Suit>> voidSuits;

  /// Unplayed cards remaining per suit.
  final Map<Suit, List<Card>> remainingBySuit;

  GameTracker._({
    required this.playedCards,
    required this.voidSuits,
    required this.remainingBySuit,
  });

  /// Builds a tracker from the current game state.
  factory GameTracker.fromState({
    required List<Trick> completedTricks,
    required Trick? currentTrick,
  }) {
    final played = <Card>{};
    final voids = <Seat, Set<Suit>>{
      for (final seat in Seat.values) seat: <Suit>{},
    };

    // Process completed tricks
    for (final trick in completedTricks) {
      _processTrick(trick, played, voids);
    }

    // Process current trick
    if (currentTrick != null) {
      _processTrick(currentTrick, played, voids);
    }

    // Build remaining cards per suit from the full 24-card deck
    final remaining = <Suit, List<Card>>{};
    for (final suit in Suit.values) {
      final cards = <Card>[];
      for (final rank in Rank.values) {
        final card = Card(suit: suit, rank: rank);
        if (!played.contains(card)) {
          cards.add(card);
        }
      }
      // Sort descending by strength
      cards.sort((a, b) => b.rank.standardRanking.compareTo(a.rank.standardRanking));
      remaining[suit] = cards;
    }

    return GameTracker._(
      playedCards: played,
      voidSuits: voids,
      remainingBySuit: remaining,
    );
  }

  static void _processTrick(
    Trick trick,
    Set<Card> played,
    Map<Seat, Set<Suit>> voids,
  ) {
    final leadSuit = trick.leadSuit;

    for (final entry in trick.cardsPlayed.entries) {
      played.add(entry.value);

      // If a player didn't follow the lead suit, they're void in it
      if (leadSuit != null && entry.value.suit != leadSuit) {
        voids[entry.key]!.add(leadSuit);
      }
    }
  }

  /// Returns true if no unplayed card in that suit outranks [card].
  bool isHighestRemaining(Card card) {
    final remaining = remainingBySuit[card.suit] ?? [];
    if (remaining.isEmpty) return false;
    // remaining is sorted descending — first element is the strongest
    return remaining.first == card ||
        card.rank.standardRanking >= remaining.first.rank.standardRanking;
  }

  /// Returns the strongest unplayed card in [suit], or null if none remain.
  Card? highestRemainingInSuit(Suit suit) {
    final remaining = remainingBySuit[suit] ?? [];
    return remaining.isEmpty ? null : remaining.first;
  }

  /// Returns true if [seat] failed to follow [suit] before.
  bool isVoidInSuit(Seat seat, Suit suit) {
    return voidSuits[seat]?.contains(suit) ?? false;
  }

  /// Returns true if any opponent of [botSeat] is not known void in [trumpSuit].
  bool opponentsMayHaveTrump(Seat botSeat, Suit trumpSuit) {
    for (final seat in Seat.values) {
      if (seat == botSeat || seat == botSeat.partner) continue;
      if (!isVoidInSuit(seat, trumpSuit)) return true;
    }
    return false;
  }

  /// Returns true if opponents are known void in trump but partner is not.
  bool onlyTeammateHasTrump(Seat botSeat, Suit trumpSuit) {
    // Both opponents must be void
    for (final seat in Seat.values) {
      if (seat == botSeat || seat == botSeat.partner) continue;
      if (!isVoidInSuit(seat, trumpSuit)) return false;
    }
    // Partner must NOT be void
    return !isVoidInSuit(botSeat.partner, trumpSuit);
  }

  /// Returns true if the Jack of [suit] has been played.
  bool jackPlayed(Suit suit) {
    return playedCards.contains(Card(suit: suit, rank: Rank.jack));
  }

  /// Returns true if the Nine of [suit] has been played.
  bool ninePlayed(Suit suit) {
    return playedCards.contains(Card(suit: suit, rank: Rank.nine));
  }

  /// Returns the number of unplayed cards in [suit].
  int remainingCount(Suit suit) {
    return remainingBySuit[suit]?.length ?? 0;
  }
}
