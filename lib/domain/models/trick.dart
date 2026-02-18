import 'package:equatable/equatable.dart';
import 'card.dart';
import 'player.dart';
import 'suit.dart';

/// Represents a single trick in progress or completed.
/// A trick consists of 4 cards played by each player in turn.
class Trick extends Equatable {
  final Map<Seat, Card> cardsPlayed; // Maps seat to card played
  final Seat leadSeat; // Who led this trick
  final Suit? leadSuit; // Suit of the first card led (null if no cards played yet)
  final Seat? winningSeat; // Current winner (null if trick not complete)
  final int points; // Total points in this trick

  const Trick({
    required this.cardsPlayed,
    required this.leadSeat,
    this.leadSuit,
    this.winningSeat,
    this.points = 0,
  });

  /// Creates an empty trick with a specific lead player
  factory Trick.empty(Seat leadSeat) {
    return Trick(
      cardsPlayed: {},
      leadSeat: leadSeat,
    );
  }

  /// Returns true if this trick is complete (all 4 players have played)
  bool get isComplete => cardsPlayed.length == 4;

  /// Returns true if this trick is empty (no cards played yet)
  bool get isEmpty => cardsPlayed.isEmpty;

  /// Returns the number of cards played so far
  int get cardCount => cardsPlayed.length;

  /// Returns the next seat to play (null if trick is complete)
  Seat? get nextToPlay {
    if (isComplete) return null;

    Seat current = leadSeat;
    for (int i = 0; i < 4; i++) {
      if (!cardsPlayed.containsKey(current)) {
        return current;
      }
      current = current.next;
    }
    return null;
  }

  /// Returns a list of cards in the order they were played
  List<Card> get cardsInOrder {
    final cards = <Card>[];
    Seat current = leadSeat;
    for (int i = 0; i < 4; i++) {
      if (cardsPlayed.containsKey(current)) {
        cards.add(cardsPlayed[current]!);
      }
      current = current.next;
    }
    return cards;
  }

  /// Adds a card to this trick
  Trick playCard(Seat seat, Card card) {
    if (cardsPlayed.containsKey(seat)) {
      throw StateError('Player at $seat has already played in this trick');
    }

    final newCardsPlayed = Map<Seat, Card>.from(cardsPlayed);
    newCardsPlayed[seat] = card;

    final newLeadSuit = leadSuit ?? card.suit;
    final newPoints = points + card.points;

    return Trick(
      cardsPlayed: newCardsPlayed,
      leadSeat: leadSeat,
      leadSuit: newLeadSuit,
      winningSeat: winningSeat, // Will be updated by TrickResolver
      points: newPoints,
    );
  }

  /// Creates a copy with updated winning seat
  Trick withWinner(Seat winner) {
    return Trick(
      cardsPlayed: cardsPlayed,
      leadSeat: leadSeat,
      leadSuit: leadSuit,
      winningSeat: winner,
      points: points,
    );
  }

  /// Serializes to JSON map
  Map<String, dynamic> toJson() => {
        'cardsPlayed': cardsPlayed.map(
            (seat, card) => MapEntry(seat.name, card.toJson())),
        'leadSeat': leadSeat.name,
        'leadSuit': leadSuit?.name,
        'winningSeat': winningSeat?.name,
        'points': points,
      };

  /// Deserializes from JSON map
  factory Trick.fromJson(Map<String, dynamic> json) {
    final cardsMap = (json['cardsPlayed'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(
        Seat.values.byName(key),
        Card.fromJson(value as String),
      ),
    );
    return Trick(
      cardsPlayed: cardsMap,
      leadSeat: Seat.values.byName(json['leadSeat'] as String),
      leadSuit: json['leadSuit'] != null
          ? Suit.values.byName(json['leadSuit'] as String)
          : null,
      winningSeat: json['winningSeat'] != null
          ? Seat.values.byName(json['winningSeat'] as String)
          : null,
      points: json['points'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [cardsPlayed, leadSeat, leadSuit, winningSeat, points];

  @override
  String toString() {
    if (isEmpty) {
      return 'Trick(empty, lead: $leadSeat)';
    }
    return 'Trick(${cardsPlayed.length} cards, lead: $leadSeat, winner: $winningSeat, points: $points)';
  }
}
