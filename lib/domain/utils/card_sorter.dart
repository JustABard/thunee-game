import '../models/card.dart';
import '../models/suit.dart';

/// Sorts a hand of cards by suit (first-appearance order) with descending
/// strength within each suit (J > 9 > A > 10 > K > Q via standardRanking).
List<Card> sortHandBySuit(List<Card> hand) {
  if (hand.length <= 1) return List.of(hand);

  // Determine suit order by first appearance in the unsorted hand
  final suitOrder = <Suit>[];
  for (final card in hand) {
    if (!suitOrder.contains(card.suit)) {
      suitOrder.add(card.suit);
    }
  }

  // Group by suit
  final groups = <Suit, List<Card>>{};
  for (final card in hand) {
    groups.putIfAbsent(card.suit, () => []).add(card);
  }

  // Sort each group descending by standard ranking (strongest first)
  for (final cards in groups.values) {
    cards.sort((a, b) => b.rank.standardRanking.compareTo(a.rank.standardRanking));
  }

  // Concatenate in first-appearance suit order
  final sorted = <Card>[];
  for (final suit in suitOrder) {
    sorted.addAll(groups[suit]!);
  }

  return sorted;
}
