import 'package:flutter_test/flutter_test.dart';
import 'package:thunee_game/domain/models/card.dart';
import 'package:thunee_game/domain/models/rank.dart';
import 'package:thunee_game/domain/models/suit.dart';
import 'package:thunee_game/domain/rules/deck_manager.dart';
import 'package:thunee_game/domain/services/rng_service.dart';
import 'package:thunee_game/utils/constants.dart';

void main() {
  group('DeckManager', () {
    late DeckManager deckManager;

    setUp(() {
      deckManager = DeckManager(RngService.unseeded());
    });

    group('createDeck', () {
      test('creates a deck with 24 cards', () {
        final deck = deckManager.createDeck();
        expect(deck.length, equals(TOTAL_CARDS));
      });

      test('includes all 6 ranks for each suit', () {
        final deck = deckManager.createDeck();

        for (final suit in Suit.values) {
          for (final rank in Rank.values) {
            final card = Card(suit: suit, rank: rank);
            expect(deck.contains(card), isTrue,
                reason: 'Deck should contain $card');
          }
        }
      });

      test('has no duplicate cards', () {
        final deck = deckManager.createDeck();
        final uniqueCards = deck.toSet();
        expect(uniqueCards.length, equals(deck.length),
            reason: 'Deck should have no duplicates');
      });

      test('total points sum to 76 (excluding last trick bonus)', () {
        final deck = deckManager.createDeck();
        final totalPoints = deck.fold<int>(0, (sum, card) => sum + card.points);
        expect(totalPoints, equals(TOTAL_CARD_POINTS));
      });
    });

    group('shuffleDeck', () {
      test('shuffled deck has same cards as original', () {
        final original = deckManager.createDeck();
        final shuffled = deckManager.shuffleDeck(original);

        expect(shuffled.length, equals(original.length));
        expect(shuffled.toSet(), equals(original.toSet()));
      });

      test('does not modify original deck', () {
        final original = deckManager.createDeck();
        final originalCopy = List<Card>.from(original);

        deckManager.shuffleDeck(original);

        expect(original, equals(originalCopy),
            reason: 'Original deck should not be modified');
      });
    });

    group('deterministic shuffling', () {
      test('same seed produces same shuffle', () {
        final manager1 = DeckManager(RngService.seeded(42));
        final manager2 = DeckManager(RngService.seeded(42));

        final deck1 = manager1.createShuffledDeck();
        final deck2 = manager2.createShuffledDeck();

        expect(deck1, equals(deck2),
            reason: 'Same seed should produce identical shuffle');
      });

      test('different seeds produce different shuffles', () {
        final manager1 = DeckManager(RngService.seeded(42));
        final manager2 = DeckManager(RngService.seeded(99));

        final deck1 = manager1.createShuffledDeck();
        final deck2 = manager2.createShuffledDeck();

        expect(deck1, isNot(equals(deck2)),
            reason: 'Different seeds should produce different shuffles');
      });
    });

    group('dealCards', () {
      test('deals exactly 6 cards to each of 4 players', () {
        final deck = deckManager.createShuffledDeck();
        final hands = deckManager.dealCards(deck);

        expect(hands.length, equals(TOTAL_PLAYERS));
        for (int i = 0; i < TOTAL_PLAYERS; i++) {
          expect(hands[i].length, equals(CARDS_PER_PLAYER),
              reason: 'Player $i should have $CARDS_PER_PLAYER cards');
        }
      });

      test('all cards are dealt (no cards left over)', () {
        final deck = deckManager.createShuffledDeck();
        final hands = deckManager.dealCards(deck);

        final allDealtCards = hands.expand((hand) => hand).toList();
        expect(allDealtCards.length, equals(TOTAL_CARDS));
      });

      test('no card is dealt to multiple players', () {
        final deck = deckManager.createShuffledDeck();
        final hands = deckManager.dealCards(deck);

        final allDealtCards = hands.expand((hand) => hand).toList();
        final uniqueCards = allDealtCards.toSet();

        expect(uniqueCards.length, equals(allDealtCards.length),
            reason: 'Each card should be dealt exactly once');
      });

      test('throws on invalid deck size', () {
        final invalidDeck = deckManager.createDeck().take(20).toList();
        expect(() => deckManager.dealCards(invalidDeck), throwsArgumentError);
      });

      test('deterministic dealing with same seed', () {
        final manager1 = DeckManager(RngService.seeded(123));
        final manager2 = DeckManager(RngService.seeded(123));

        final hands1 = manager1.dealNewGame();
        final hands2 = manager2.dealNewGame();

        expect(hands1, equals(hands2),
            reason: 'Same seed should produce identical deals');
      });
    });

    group('dealNewGame', () {
      test('creates and deals a complete game', () {
        final hands = deckManager.dealNewGame();

        expect(hands.length, equals(TOTAL_PLAYERS));
        for (final hand in hands) {
          expect(hand.length, equals(CARDS_PER_PLAYER));
        }
      });
    });
  });
}
