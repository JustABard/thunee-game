import '../models/card.dart';
import '../models/suit.dart';

/// Canonical suit order: alternating red/black for visual clarity.
const _suitOrder = [Suit.hearts, Suit.clubs, Suit.diamonds, Suit.spades];

/// Sorts a hand of cards by suit (consistent canonical order) with descending
/// strength within each suit (J > 9 > A > 10 > K > Q via standardRanking).
///
/// Suits are grouped by count (most cards first) within the canonical order,
/// so the hand feels natural: your longest suit appears first.
List<Card> sortHandBySuit(List<Card> hand) {
  if (hand.length <= 1) return List.of(hand);

  // Group by suit
  final groups = <Suit, List<Card>>{};
  for (final card in hand) {
    groups.putIfAbsent(card.suit, () => []).add(card);
  }

  // Sort each group descending by standard ranking (strongest first)
  for (final cards in groups.values) {
    cards.sort((a, b) => b.rank.standardRanking.compareTo(a.rank.standardRanking));
  }

  // Order suits: sort by count descending, then by canonical order for ties
  final presentSuits = groups.keys.toList();
  presentSuits.sort((a, b) {
    final countCmp = groups[b]!.length.compareTo(groups[a]!.length);
    if (countCmp != 0) return countCmp;
    return _suitOrder.indexOf(a).compareTo(_suitOrder.indexOf(b));
  });

  // Concatenate
  final sorted = <Card>[];
  for (final suit in presentSuits) {
    sorted.addAll(groups[suit]!);
  }

  return sorted;
}
