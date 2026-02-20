import 'package:flutter_test/flutter_test.dart';
import 'package:thunee_game/domain/models/card.dart';
import 'package:thunee_game/domain/models/player.dart';
import 'package:thunee_game/domain/models/rank.dart';
import 'package:thunee_game/domain/models/suit.dart';
import 'package:thunee_game/domain/models/trick.dart';
import 'package:thunee_game/domain/rules/card_ranker.dart';
import 'package:thunee_game/domain/rules/trick_resolver.dart';

void main() {
  late TrickResolver resolver;
  late CardRanker ranker;

  setUp(() {
    ranker = CardRanker();
    resolver = TrickResolver(ranker);
  });

  group('TrickResolver - Follow Suit Validation', () {
    test('first card of trick is always valid', () {
      final player = Player(
        id: '1',
        name: 'Player 1',
        seat: Seat.south,
        hand: [
          Card(suit: Suit.hearts, rank: Rank.jack),
          Card(suit: Suit.spades, rank: Rank.nine),
        ],
        isBot: false,
      );

      final trick = Trick.empty(Seat.south);
      final card = Card(suit: Suit.hearts, rank: Rank.jack);

      final result = resolver.validateCardPlay(
        card: card,
        player: player,
        trick: trick,
      );

      expect(result.isValid, isTrue);
    });

    test('must follow suit when holding lead suit', () {
      final player = Player(
        id: '1',
        name: 'Player 1',
        seat: Seat.west,
        hand: [
          Card(suit: Suit.hearts, rank: Rank.jack),
          Card(suit: Suit.hearts, rank: Rank.nine),
          Card(suit: Suit.spades, rank: Rank.ace),
        ],
        isBot: false,
      );

      final trick = Trick.empty(Seat.south).playCard(
        Seat.south,
        Card(suit: Suit.hearts, rank: Rank.king),
      );

      // Try to play spades when holding hearts
      final result = resolver.validateCardPlay(
        card: Card(suit: Suit.spades, rank: Rank.ace),
        player: player,
        trick: trick,
      );

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('Must follow suit'));
    });

    test('can play hearts when hearts was led and player has hearts', () {
      final player = Player(
        id: '1',
        name: 'Player 1',
        seat: Seat.west,
        hand: [
          Card(suit: Suit.hearts, rank: Rank.jack),
          Card(suit: Suit.spades, rank: Rank.ace),
        ],
        isBot: false,
      );

      final trick = Trick.empty(Seat.south).playCard(
        Seat.south,
        Card(suit: Suit.hearts, rank: Rank.king),
      );

      final result = resolver.validateCardPlay(
        card: Card(suit: Suit.hearts, rank: Rank.jack),
        player: player,
        trick: trick,
      );

      expect(result.isValid, isTrue);
    });

    test('can play any card when void in lead suit', () {
      final player = Player(
        id: '1',
        name: 'Player 1',
        seat: Seat.west,
        hand: [
          Card(suit: Suit.spades, rank: Rank.jack),
          Card(suit: Suit.spades, rank: Rank.nine),
          Card(suit: Suit.diamonds, rank: Rank.ace),
        ],
        isBot: false,
      );

      final trick = Trick.empty(Seat.south).playCard(
        Seat.south,
        Card(suit: Suit.hearts, rank: Rank.king), // Hearts led
      );

      // Player has no hearts, can play any card
      final result = resolver.validateCardPlay(
        card: Card(suit: Suit.spades, rank: Rank.jack),
        player: player,
        trick: trick,
      );

      expect(result.isValid, isTrue);
    });
  });

  group('TrickResolver - Winner Determination', () {
    test('highest trump wins when multiple trumps played', () {
      final trick = Trick.empty(Seat.south)
          .playCard(Seat.south, Card(suit: Suit.hearts, rank: Rank.nine))
          .playCard(Seat.west, Card(suit: Suit.hearts, rank: Rank.jack))
          .playCard(Seat.north, Card(suit: Suit.hearts, rank: Rank.ace))
          .playCard(Seat.east, Card(suit: Suit.hearts, rank: Rank.ten));

      final winner = resolver.determineWinner(
        trick: trick,
        trumpSuit: Suit.hearts,
      );

      // Jack > 9 > Ace > 10 in standard ranking
      expect(winner, equals(Seat.west)); // Jack wins
    });

    test('trump cuts win over non-trump', () {
      final trick = Trick.empty(Seat.south)
          .playCard(Seat.south, Card(suit: Suit.spades, rank: Rank.jack)) // Lead
          .playCard(Seat.west, Card(suit: Suit.spades, rank: Rank.nine))
          .playCard(Seat.north, Card(suit: Suit.hearts, rank: Rank.queen)) // Trump
          .playCard(Seat.east, Card(suit: Suit.spades, rank: Rank.ace));

      final winner = resolver.determineWinner(
        trick: trick,
        trumpSuit: Suit.hearts,
      );

      expect(winner, equals(Seat.north)); // Trump queen wins
    });

    test('highest of lead suit wins when no trump played', () {
      final trick = Trick.empty(Seat.south)
          .playCard(Seat.south, Card(suit: Suit.spades, rank: Rank.ten))
          .playCard(Seat.west, Card(suit: Suit.spades, rank: Rank.jack))
          .playCard(Seat.north, Card(suit: Suit.spades, rank: Rank.nine))
          .playCard(Seat.east, Card(suit: Suit.diamonds, rank: Rank.jack)); // Off-suit

      final winner = resolver.determineWinner(
        trick: trick,
        trumpSuit: Suit.hearts,
      );

      // Jack > 9 > 10 in lead suit (spades)
      expect(winner, equals(Seat.west)); // Jack of spades wins
    });

    test('Royals ranking: Queen > King > 10 > Ace > 9 > Jack', () {
      final trick = Trick.empty(Seat.south)
          .playCard(Seat.south, Card(suit: Suit.hearts, rank: Rank.jack))
          .playCard(Seat.west, Card(suit: Suit.hearts, rank: Rank.queen))
          .playCard(Seat.north, Card(suit: Suit.hearts, rank: Rank.king))
          .playCard(Seat.east, Card(suit: Suit.hearts, rank: Rank.nine));

      final winner = resolver.determineWinner(
        trick: trick,
        trumpSuit: Suit.hearts,
        isRoyalsMode: true,
      );

      expect(winner, equals(Seat.west)); // Queen wins in Royals mode
    });

    test('standard ranking: Jack > 9 > Ace > 10 > King > Queen', () {
      final trick = Trick.empty(Seat.south)
          .playCard(Seat.south, Card(suit: Suit.hearts, rank: Rank.queen))
          .playCard(Seat.west, Card(suit: Suit.hearts, rank: Rank.jack))
          .playCard(Seat.north, Card(suit: Suit.hearts, rank: Rank.king))
          .playCard(Seat.east, Card(suit: Suit.hearts, rank: Rank.nine));

      final winner = resolver.determineWinner(
        trick: trick,
        trumpSuit: Suit.hearts,
        isRoyalsMode: false,
      );

      expect(winner, equals(Seat.west)); // Jack wins in standard mode
    });

    test('first trump played wins when all others follow lead suit', () {
      final trick = Trick.empty(Seat.south)
          .playCard(Seat.south, Card(suit: Suit.spades, rank: Rank.jack))
          .playCard(Seat.west, Card(suit: Suit.hearts, rank: Rank.queen)) // Trump
          .playCard(Seat.north, Card(suit: Suit.spades, rank: Rank.ace))
          .playCard(Seat.east, Card(suit: Suit.spades, rank: Rank.nine));

      final winner = resolver.determineWinner(
        trick: trick,
        trumpSuit: Suit.hearts,
      );

      expect(winner, equals(Seat.west)); // Only trump wins
    });
  });

  group('TrickResolver - Edge Cases', () {
    test('void suit allows playing trump', () {
      final player = Player(
        id: '1',
        name: 'Player 1',
        seat: Seat.west,
        hand: [
          Card(suit: Suit.hearts, rank: Rank.queen), // Trump
          Card(suit: Suit.diamonds, rank: Rank.ace),
        ],
        isBot: false,
      );

      final trick = Trick.empty(Seat.south).playCard(
        Seat.south,
        Card(suit: Suit.spades, rank: Rank.jack), // Spades led
      );

      // Player has no spades, can cut with trump
      final result = resolver.validateCardPlay(
        card: Card(suit: Suit.hearts, rank: Rank.queen),
        player: player,
        trick: trick,
      );

      expect(result.isValid, isTrue);
    });

    test('all trump trick follows standard/royals ranking', () {
      // All hearts, hearts is trump
      final trickStandard = Trick.empty(Seat.south)
          .playCard(Seat.south, Card(suit: Suit.hearts, rank: Rank.ace))
          .playCard(Seat.west, Card(suit: Suit.hearts, rank: Rank.nine))
          .playCard(Seat.north, Card(suit: Suit.hearts, rank: Rank.jack))
          .playCard(Seat.east, Card(suit: Suit.hearts, rank: Rank.ten));

      final winnerStandard = resolver.determineWinner(
        trick: trickStandard,
        trumpSuit: Suit.hearts,
        isRoyalsMode: false,
      );

      expect(winnerStandard, equals(Seat.north)); // Jack wins in standard

      final trickRoyals = Trick.empty(Seat.south)
          .playCard(Seat.south, Card(suit: Suit.hearts, rank: Rank.queen))
          .playCard(Seat.west, Card(suit: Suit.hearts, rank: Rank.king))
          .playCard(Seat.north, Card(suit: Suit.hearts, rank: Rank.jack))
          .playCard(Seat.east, Card(suit: Suit.hearts, rank: Rank.nine));

      final winnerRoyals = resolver.determineWinner(
        trick: trickRoyals,
        trumpSuit: Suit.hearts,
        isRoyalsMode: true,
      );

      expect(winnerRoyals, equals(Seat.south)); // Queen wins in Royals
    });

    test('throws on incomplete trick when determining winner', () {
      final trick = Trick.empty(Seat.south)
          .playCard(Seat.south, Card(suit: Suit.hearts, rank: Rank.jack))
          .playCard(Seat.west, Card(suit: Suit.hearts, rank: Rank.nine));

      expect(
        () => resolver.determineWinner(trick: trick, trumpSuit: Suit.hearts),
        throwsStateError,
      );
    });
  });

  group('TrickResolver - Legal Cards', () {
    test('can play any card when leading', () {
      final player = Player(
        id: '1',
        name: 'Player 1',
        seat: Seat.south,
        hand: [
          Card(suit: Suit.hearts, rank: Rank.jack),
          Card(suit: Suit.spades, rank: Rank.nine),
          Card(suit: Suit.diamonds, rank: Rank.ace),
        ],
        isBot: false,
      );

      final trick = Trick.empty(Seat.south);
      final legalCards = resolver.getLegalCards(player: player, trick: trick);

      expect(legalCards.length, equals(3));
      expect(legalCards, containsAll(player.hand));
    });

    test('must return only lead suit cards when holding lead suit', () {
      final player = Player(
        id: '1',
        name: 'Player 1',
        seat: Seat.west,
        hand: [
          Card(suit: Suit.hearts, rank: Rank.jack),
          Card(suit: Suit.hearts, rank: Rank.nine),
          Card(suit: Suit.spades, rank: Rank.ace),
        ],
        isBot: false,
      );

      final trick = Trick.empty(Seat.south).playCard(
        Seat.south,
        Card(suit: Suit.hearts, rank: Rank.king),
      );

      final legalCards = resolver.getLegalCards(player: player, trick: trick);

      expect(legalCards.length, equals(2));
      expect(legalCards.every((c) => c.suit == Suit.hearts), isTrue);
    });

    test('returns all cards when void in lead suit', () {
      final player = Player(
        id: '1',
        name: 'Player 1',
        seat: Seat.west,
        hand: [
          Card(suit: Suit.spades, rank: Rank.jack),
          Card(suit: Suit.diamonds, rank: Rank.nine),
          Card(suit: Suit.clubs, rank: Rank.ace),
        ],
        isBot: false,
      );

      final trick = Trick.empty(Seat.south).playCard(
        Seat.south,
        Card(suit: Suit.hearts, rank: Rank.king), // Hearts led
      );

      final legalCards = resolver.getLegalCards(player: player, trick: trick);

      expect(legalCards.length, equals(3));
      expect(legalCards, containsAll(player.hand));
    });
  });

  group('TrickResolver - Utility Methods', () {
    test('willCardWin correctly predicts trump cut', () {
      final trick = Trick.empty(Seat.south)
          .playCard(Seat.south, Card(suit: Suit.spades, rank: Rank.jack));

      final trumpCard = Card(suit: Suit.hearts, rank: Rank.queen);

      final willWin = resolver.willCardWin(
        card: trumpCard,
        trick: trick,
        trumpSuit: Suit.hearts,
      );

      expect(willWin, isTrue);
    });

    test('willCardWin returns false for weaker card', () {
      final trick = Trick.empty(Seat.south)
          .playCard(Seat.south, Card(suit: Suit.hearts, rank: Rank.jack));

      final weakerCard = Card(suit: Suit.hearts, rank: Rank.queen);

      final willWin = resolver.willCardWin(
        card: weakerCard,
        trick: trick,
        trumpSuit: Suit.hearts,
        isRoyalsMode: false,
      );

      expect(willWin, isFalse); // Queen < Jack in standard mode
    });

    test('getCurrentWinningCard returns correct card', () {
      final trick = Trick.empty(Seat.south)
          .playCard(Seat.south, Card(suit: Suit.hearts, rank: Rank.nine))
          .playCard(Seat.west, Card(suit: Suit.hearts, rank: Rank.jack));

      final winningCard = resolver.getCurrentWinningCard(
        trick: trick,
        trumpSuit: Suit.hearts,
      );

      expect(winningCard, equals(Card(suit: Suit.hearts, rank: Rank.jack)));
    });

    test('getCurrentWinningSeat returns correct seat', () {
      // Use proper turn order: South → East → North → West
      final trick = Trick.empty(Seat.south)
          .playCard(Seat.south, Card(suit: Suit.hearts, rank: Rank.nine))
          .playCard(Seat.east, Card(suit: Suit.hearts, rank: Rank.jack))
          .playCard(Seat.north, Card(suit: Suit.hearts, rank: Rank.ace));

      final winningSeat = resolver.getCurrentWinningSeat(
        trick: trick,
        trumpSuit: Suit.hearts,
      );

      expect(winningSeat, equals(Seat.east)); // Jack > 9 > Ace
    });
  });
}
