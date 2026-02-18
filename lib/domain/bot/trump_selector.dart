import '../models/card.dart';
import '../models/rank.dart';
import '../models/suit.dart';

/// Selects the best trump suit for a bot's hand using a scoring heuristic.
///
/// Scoring per suit:
///   +50  Jodi (K+Q same suit)
///   +40  Jack
///   +25  Nine
///   +15  Ace
///   +10  per card count
///   +5   Ten
Suit selectBestTrumpSuit(List<Card> hand) {
  Suit bestSuit = hand.first.suit;
  int bestScore = -1;

  for (final suit in Suit.values) {
    final cards = hand.where((c) => c.suit == suit).toList();
    if (cards.isEmpty) continue;

    int score = cards.length * 10; // +10 per card

    bool hasKing = false;
    bool hasQueen = false;

    for (final card in cards) {
      switch (card.rank) {
        case Rank.jack:
          score += 40;
          break;
        case Rank.nine:
          score += 25;
          break;
        case Rank.ace:
          score += 15;
          break;
        case Rank.ten:
          score += 5;
          break;
        case Rank.king:
          hasKing = true;
          break;
        case Rank.queen:
          hasQueen = true;
          break;
      }
    }

    // Jodi bonus
    if (hasKing && hasQueen) {
      score += 50;
    }

    if (score > bestScore) {
      bestScore = score;
      bestSuit = suit;
    }
  }

  return bestSuit;
}
