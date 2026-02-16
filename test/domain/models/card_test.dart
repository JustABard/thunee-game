import 'package:flutter_test/flutter_test.dart';
import 'package:thunee_game/domain/models/card.dart';
import 'package:thunee_game/domain/models/rank.dart';
import 'package:thunee_game/domain/models/suit.dart';

void main() {
  group('Card', () {
    group('point values', () {
      test('Jack has 30 points', () {
        final card = Card(suit: Suit.hearts, rank: Rank.jack);
        expect(card.points, equals(30));
      });

      test('Nine has 20 points', () {
        final card = Card(suit: Suit.spades, rank: Rank.nine);
        expect(card.points, equals(20));
      });

      test('Ace has 11 points', () {
        final card = Card(suit: Suit.diamonds, rank: Rank.ace);
        expect(card.points, equals(11));
      });

      test('Ten has 10 points', () {
        final card = Card(suit: Suit.clubs, rank: Rank.ten);
        expect(card.points, equals(10));
      });

      test('King has 3 points', () {
        final card = Card(suit: Suit.hearts, rank: Rank.king);
        expect(card.points, equals(3));
      });

      test('Queen has 2 points', () {
        final card = Card(suit: Suit.spades, rank: Rank.queen);
        expect(card.points, equals(2));
      });
    });

    group('equality', () {
      test('cards with same suit and rank are equal', () {
        final card1 = Card(suit: Suit.hearts, rank: Rank.jack);
        final card2 = Card(suit: Suit.hearts, rank: Rank.jack);
        expect(card1, equals(card2));
      });

      test('cards with different suits are not equal', () {
        final card1 = Card(suit: Suit.hearts, rank: Rank.jack);
        final card2 = Card(suit: Suit.spades, rank: Rank.jack);
        expect(card1, isNot(equals(card2)));
      });

      test('cards with different ranks are not equal', () {
        final card1 = Card(suit: Suit.hearts, rank: Rank.jack);
        final card2 = Card(suit: Suit.hearts, rank: Rank.nine);
        expect(card1, isNot(equals(card2)));
      });
    });

    group('display', () {
      test('displayName returns readable format', () {
        final card = Card(suit: Suit.hearts, rank: Rank.jack);
        expect(card.displayName, equals('Jack of Hearts'));
      });

      test('shortName returns symbol format', () {
        final card = Card(suit: Suit.hearts, rank: Rank.jack);
        expect(card.shortName, equals('J♥'));
      });

      test('toString returns shortName', () {
        final card = Card(suit: Suit.spades, rank: Rank.ten);
        expect(card.toString(), equals('10♠'));
      });
    });

    group('fromString', () {
      test('parses Jack of Hearts', () {
        final card = Card.fromString('J♥');
        expect(card.suit, equals(Suit.hearts));
        expect(card.rank, equals(Rank.jack));
      });

      test('parses 10 of Spades', () {
        final card = Card.fromString('10♠');
        expect(card.suit, equals(Suit.spades));
        expect(card.rank, equals(Rank.ten));
      });

      test('throws on invalid string', () {
        expect(() => Card.fromString('X'), throwsArgumentError);
      });

      test('throws on invalid suit symbol', () {
        expect(() => Card.fromString('J?'), throwsArgumentError);
      });

      test('throws on invalid rank symbol', () {
        expect(() => Card.fromString('X♥'), throwsArgumentError);
      });
    });
  });

  group('Rank', () {
    test('standardRanking has correct order (J>9>A>10>K>Q)', () {
      expect(Rank.jack.standardRanking, greaterThan(Rank.nine.standardRanking));
      expect(Rank.nine.standardRanking, greaterThan(Rank.ace.standardRanking));
      expect(Rank.ace.standardRanking, greaterThan(Rank.ten.standardRanking));
      expect(Rank.ten.standardRanking, greaterThan(Rank.king.standardRanking));
      expect(Rank.king.standardRanking, greaterThan(Rank.queen.standardRanking));
    });

    test('royalsRanking has correct order (Q>K>10>A>9>J)', () {
      expect(Rank.queen.royalsRanking, greaterThan(Rank.king.royalsRanking));
      expect(Rank.king.royalsRanking, greaterThan(Rank.ten.royalsRanking));
      expect(Rank.ten.royalsRanking, greaterThan(Rank.ace.royalsRanking));
      expect(Rank.ace.royalsRanking, greaterThan(Rank.nine.royalsRanking));
      expect(Rank.nine.royalsRanking, greaterThan(Rank.jack.royalsRanking));
    });
  });

  group('Suit', () {
    test('hearts is red', () {
      expect(Suit.hearts.isRed, isTrue);
      expect(Suit.hearts.isBlack, isFalse);
    });

    test('diamonds is red', () {
      expect(Suit.diamonds.isRed, isTrue);
      expect(Suit.diamonds.isBlack, isFalse);
    });

    test('clubs is black', () {
      expect(Suit.clubs.isBlack, isTrue);
      expect(Suit.clubs.isRed, isFalse);
    });

    test('spades is black', () {
      expect(Suit.spades.isBlack, isTrue);
      expect(Suit.spades.isRed, isFalse);
    });
  });
}
