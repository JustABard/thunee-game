import '../models/card.dart';
import '../models/rank.dart';
import '../models/suit.dart';

/// Handles card ranking for trick resolution.
/// Supports both standard ranking and Royals (reversed) ranking.
class CardRanker {
  /// Compares two cards to determine which is higher.
  /// Returns positive if card1 > card2, negative if card1 < card2, zero if equal.
  ///
  /// Parameters:
  /// - card1: First card to compare
  /// - card2: Second card to compare
  /// - trumpSuit: The trump suit for this round
  /// - leadSuit: The suit that was led for this trick
  /// - isRoyalsMode: Whether Royals ranking is active (default: false)
  ///
  /// Rules:
  /// 1. Trump cards always beat non-trump cards
  /// 2. If both are trump, compare by rank
  /// 3. If both are lead suit (non-trump), compare by rank
  /// 4. If neither is trump nor lead suit, they're equal (shouldn't happen in valid play)
  /// 5. Lead suit beats off-suits (non-trump, non-lead)
  int compareCards({
    required Card card1,
    required Card card2,
    required Suit trumpSuit,
    required Suit leadSuit,
    bool isRoyalsMode = false,
  }) {
    final isTrump1 = card1.suit == trumpSuit;
    final isTrump2 = card2.suit == trumpSuit;
    final isLead1 = card1.suit == leadSuit;
    final isLead2 = card2.suit == leadSuit;

    // Case 1: Both are trump - compare ranks
    if (isTrump1 && isTrump2) {
      return _compareRanks(card1.rank, card2.rank, isRoyalsMode);
    }

    // Case 2: Only card1 is trump - card1 wins
    if (isTrump1) {
      return 1;
    }

    // Case 3: Only card2 is trump - card2 wins
    if (isTrump2) {
      return -1;
    }

    // Case 4: Both are lead suit (non-trump) - compare ranks
    if (isLead1 && isLead2) {
      return _compareRanks(card1.rank, card2.rank, isRoyalsMode);
    }

    // Case 5: Only card1 is lead suit - card1 wins
    if (isLead1) {
      return 1;
    }

    // Case 6: Only card2 is lead suit - card2 wins
    if (isLead2) {
      return -1;
    }

    // Case 7: Neither is trump nor lead suit - equal (shouldn't happen)
    return 0;
  }

  /// Compares two ranks.
  /// Returns positive if rank1 > rank2, negative if rank1 < rank2, zero if equal.
  int _compareRanks(Rank rank1, Rank rank2, bool isRoyalsMode) {
    if (rank1 == rank2) return 0;

    final ranking1 = isRoyalsMode ? rank1.royalsRanking : rank1.standardRanking;
    final ranking2 = isRoyalsMode ? rank2.royalsRanking : rank2.standardRanking;

    return ranking1.compareTo(ranking2);
  }

  /// Determines the winning card from a list of cards.
  /// Returns the index of the winning card.
  ///
  /// Parameters:
  /// - cards: List of cards (must have 4 cards)
  /// - trumpSuit: The trump suit
  /// - leadSuit: The suit that was led (suit of first card)
  /// - isRoyalsMode: Whether Royals ranking is active
  int determineWinningCardIndex({
    required List<Card> cards,
    required Suit trumpSuit,
    required Suit leadSuit,
    bool isRoyalsMode = false,
  }) {
    if (cards.isEmpty) {
      throw ArgumentError('Cannot determine winner from empty card list');
    }

    int winningIndex = 0;
    Card winningCard = cards[0];

    for (int i = 1; i < cards.length; i++) {
      final comparison = compareCards(
        card1: cards[i],
        card2: winningCard,
        trumpSuit: trumpSuit,
        leadSuit: leadSuit,
        isRoyalsMode: isRoyalsMode,
      );

      if (comparison > 0) {
        winningIndex = i;
        winningCard = cards[i];
      }
    }

    return winningIndex;
  }

  /// Returns true if card1 beats card2
  bool beats({
    required Card card1,
    required Card card2,
    required Suit trumpSuit,
    required Suit leadSuit,
    bool isRoyalsMode = false,
  }) {
    return compareCards(
          card1: card1,
          card2: card2,
          trumpSuit: trumpSuit,
          leadSuit: leadSuit,
          isRoyalsMode: isRoyalsMode,
        ) >
        0;
  }
}
