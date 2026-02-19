import '../models/card.dart';
import '../models/rank.dart';
import '../models/suit.dart';
import '../services/rng_service.dart';
import '../../utils/constants.dart';

/// Manages deck creation, shuffling, and dealing for Thunee.
class DeckManager {
  final RngService _rng;

  DeckManager(this._rng);

  /// Creates a standard 24-card Thunee deck.
  /// Includes 6 ranks (J, 9, A, 10, K, Q) × 4 suits
  List<Card> createDeck() {
    final deck = <Card>[];

    for (final suit in Suit.values) {
      for (final rank in Rank.values) {
        deck.add(Card(suit: suit, rank: rank));
      }
    }

    return deck;
  }

  /// Shuffles a deck using the internal RNG.
  /// If using a seeded RNG, this will be deterministic.
  List<Card> shuffleDeck(List<Card> deck) {
    final deckCopy = List<Card>.from(deck);
    return _rng.shuffle(deckCopy);
  }

  /// Creates and shuffles a new deck
  List<Card> createShuffledDeck() {
    final deck = createDeck();
    return shuffleDeck(deck);
  }

  /// Deals cards to players from a shuffled deck.
  /// Returns a list of 4 hands (6 cards each).
  /// Index 0 = South, 1 = West, 2 = North, 3 = East
  List<List<Card>> dealCards(List<Card> shuffledDeck) {
    if (shuffledDeck.length != TOTAL_CARDS) {
      throw ArgumentError(
        'Deck must have exactly $TOTAL_CARDS cards, got ${shuffledDeck.length}',
      );
    }

    final hands = <List<Card>>[];
    for (int i = 0; i < TOTAL_PLAYERS; i++) {
      hands.add([]);
    }

    // Deal cards round-robin style (1 card to each player, then repeat)
    for (int cardIndex = 0; cardIndex < shuffledDeck.length; cardIndex++) {
      final playerIndex = cardIndex % TOTAL_PLAYERS;
      hands[playerIndex].add(shuffledDeck[cardIndex]);
    }

    // Verify each hand has exactly 6 cards
    for (int i = 0; i < TOTAL_PLAYERS; i++) {
      if (hands[i].length != CARDS_PER_PLAYER) {
        throw StateError(
          'Player $i should have $CARDS_PER_PLAYER cards, got ${hands[i].length}',
        );
      }
    }

    return hands;
  }

  /// Convenience method: creates, shuffles, and deals a new deck
  List<List<Card>> dealNewGame() {
    final deck = createShuffledDeck();
    return dealCards(deck);
  }

  /// Deals cards in two rounds per Thunee rules:
  ///   - 4 cards dealt initially (bidding happens on these)
  ///   - 2 cards held back and given to each player after bidding
  /// Returns a record with `initial` (4 cards each) and `remaining` (2 cards each).
  ({List<List<Card>> initial, List<List<Card>> remaining}) dealSplit() {
    final deck = createShuffledDeck();

    final initial = List.generate(TOTAL_PLAYERS, (_) => <Card>[]);
    final remaining = List.generate(TOTAL_PLAYERS, (_) => <Card>[]);

    // First 16 cards go to players round-robin (4 each)
    for (int i = 0; i < TOTAL_PLAYERS * INITIAL_DEAL_CARDS; i++) {
      initial[i % TOTAL_PLAYERS].add(deck[i]);
    }

    // Remaining 8 cards (2 each) held back until bidding completes
    for (int i = TOTAL_PLAYERS * INITIAL_DEAL_CARDS; i < deck.length; i++) {
      remaining[i % TOTAL_PLAYERS].add(deck[i]);
    }

    // Safety: verify no duplicates across all hands
    assert(() {
      final all = <Card>{};
      for (final hand in initial) {
        for (final card in hand) {
          if (!all.add(card)) {
            throw StateError('Duplicate card dealt: $card');
          }
        }
      }
      for (final hand in remaining) {
        for (final card in hand) {
          if (!all.add(card)) {
            throw StateError('Duplicate card in remaining: $card');
          }
        }
      }
      return true;
    }());

    return (initial: initial, remaining: remaining);
  }
}
