import 'package:equatable/equatable.dart';
import 'rank.dart';
import 'suit.dart';

/// Represents a playing card in the Thunee game.
class Card extends Equatable {
  final Suit suit;
  final Rank rank;

  const Card({
    required this.suit,
    required this.rank,
  });

  /// Returns the point value of this card
  int get points => rank.points;

  /// Returns a human-readable string representation
  String get displayName => '${rank.displayName} of ${suit.displayName}';

  /// Returns a short string representation (e.g., "J♥", "10♠")
  String get shortName => '${rank.symbol}${suit.symbol}';

  @override
  List<Object?> get props => [suit, rank];

  @override
  String toString() => shortName;

  /// Creates a card from a short string (e.g., "J♥", "10♠")
  factory Card.fromString(String str) {
    if (str.length < 2) {
      throw ArgumentError('Invalid card string: $str');
    }

    // Extract rank and suit symbols
    final suitSymbol = str.substring(str.length - 1);
    final rankSymbol = str.substring(0, str.length - 1);

    // Find matching suit
    final suit = Suit.values.firstWhere(
      (s) => s.symbol == suitSymbol,
      orElse: () => throw ArgumentError('Invalid suit symbol: $suitSymbol'),
    );

    // Find matching rank
    final rank = Rank.values.firstWhere(
      (r) => r.symbol == rankSymbol,
      orElse: () => throw ArgumentError('Invalid rank symbol: $rankSymbol'),
    );

    return Card(suit: suit, rank: rank);
  }
}
