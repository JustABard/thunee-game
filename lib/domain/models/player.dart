import 'package:equatable/equatable.dart';
import 'card.dart';
import 'suit.dart';

/// Represents a player's seat position at the table.
/// Turn order is anti-clockwise (right-hand player goes next):
///   South → East → North → West → South
enum Seat {
  south, // Player 1 (bottom)
  west, // Player 2 (left)
  north, // Player 3 (top)
  east; // Player 4 (right)

  /// Returns the next seat in anti-clockwise order (right-hand player).
  ///   South → East → North → West → South
  Seat get next {
    switch (this) {
      case Seat.south:
        return Seat.east;
      case Seat.east:
        return Seat.north;
      case Seat.north:
        return Seat.west;
      case Seat.west:
        return Seat.south;
    }
  }

  /// Returns the partner's seat (opposite position)
  Seat get partner {
    switch (this) {
      case Seat.south:
        return Seat.north;
      case Seat.west:
        return Seat.east;
      case Seat.north:
        return Seat.south;
      case Seat.east:
        return Seat.west;
    }
  }

  /// Returns team number (0 or 1)
  /// Team 0: South + North
  /// Team 1: West + East
  int get teamNumber {
    switch (this) {
      case Seat.south:
      case Seat.north:
        return 0;
      case Seat.west:
      case Seat.east:
        return 1;
    }
  }
}

/// Represents a player in the game
class Player extends Equatable {
  final String id;
  final String name;
  final Seat seat;
  final List<Card> hand;
  final bool isBot;

  const Player({
    required this.id,
    required this.name,
    required this.seat,
    required this.hand,
    required this.isBot,
  });

  /// Creates a copy with updated fields
  Player copyWith({
    String? id,
    String? name,
    Seat? seat,
    List<Card>? hand,
    bool? isBot,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      seat: seat ?? this.seat,
      hand: hand ?? this.hand,
      isBot: isBot ?? this.isBot,
    );
  }

  /// Returns the team number this player belongs to
  int get teamNumber => seat.teamNumber;

  /// Returns the partner's seat
  Seat get partnerSeat => seat.partner;

  /// Checks if this player has a specific card
  bool hasCard(Card card) => hand.contains(card);

  /// Checks if this player has any cards of a specific suit
  bool hasSuit(Suit suit) => hand.any((card) => card.suit == suit);

  /// Returns all cards of a specific suit
  List<Card> cardsOfSuit(Suit suit) =>
      hand.where((card) => card.suit == suit).toList();

  /// Returns the number of cards in hand
  int get handSize => hand.length;

  /// Checks if hand is empty
  bool get hasNoCards => hand.isEmpty;

  @override
  List<Object?> get props => [id, name, seat, hand, isBot];

  @override
  String toString() => 'Player($name, $seat, ${hand.length} cards)';
}
