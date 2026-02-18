import 'package:equatable/equatable.dart';
import 'player.dart';
import 'card.dart';
import 'suit.dart';

/// Categories of calls that can be made in Thunee
enum CallCategory {
  bid, // Numeric bidding (10, 20, 30, etc.)
  pass, // Pass on bidding
  thunee, // Regular Thunee
  royals, // Royals game
  blindThunee, // Blind Thunee
  blindRoyals, // Blind Royals
  jodi, // King+Queen or Jack+Queen+King combo
  double, // Double the last trick
  kunuck, // Kunuck on last trick
}

/// Base class for all call data
abstract class CallData extends Equatable {
  final CallCategory category;
  final Seat caller;

  const CallData({
    required this.category,
    required this.caller,
  });

  /// Serializes to JSON map (polymorphic via 'category' discriminator)
  Map<String, dynamic> toJson() => {
        'category': category.name,
        'caller': caller.name,
      };

  /// Deserializes from JSON map (dispatches to correct subclass)
  static CallData fromJson(Map<String, dynamic> json) {
    final category = CallCategory.values.byName(json['category'] as String);
    switch (category) {
      case CallCategory.bid:
        return BidCall.fromJson(json);
      case CallCategory.pass:
        return PassCall.fromJson(json);
      case CallCategory.thunee:
        return ThuneeCall.fromJson(json);
      case CallCategory.royals:
        return RoyalsCall.fromJson(json);
      case CallCategory.blindThunee:
        return BlindThuneeCall.fromJson(json);
      case CallCategory.blindRoyals:
        return BlindRoyalsCall.fromJson(json);
      case CallCategory.jodi:
        return JodiCall.fromJson(json);
      case CallCategory.double:
        return DoubleCall.fromJson(json);
      case CallCategory.kunuck:
        return KunuckCall.fromJson(json);
    }
  }

  @override
  List<Object?> get props => [category, caller];
}

/// Numeric bid call
class BidCall extends CallData {
  final int amount; // 10, 20, 30, etc.

  const BidCall({
    required Seat caller,
    required this.amount,
  }) : super(category: CallCategory.bid, caller: caller);

  @override
  Map<String, dynamic> toJson() => {...super.toJson(), 'amount': amount};

  factory BidCall.fromJson(Map<String, dynamic> json) => BidCall(
        caller: Seat.values.byName(json['caller'] as String),
        amount: json['amount'] as int,
      );

  @override
  List<Object?> get props => [...super.props, amount];

  @override
  String toString() => 'Bid($amount by $caller)';
}

/// Pass call
class PassCall extends CallData {
  const PassCall({
    required Seat caller,
  }) : super(category: CallCategory.pass, caller: caller);

  factory PassCall.fromJson(Map<String, dynamic> json) => PassCall(
        caller: Seat.values.byName(json['caller'] as String),
      );

  @override
  String toString() => 'Pass($caller)';
}

/// Thunee call (win all 6 tricks)
class ThuneeCall extends CallData {
  final Suit? trumpSuit; // Set when first card is led

  const ThuneeCall({
    required Seat caller,
    this.trumpSuit,
  }) : super(category: CallCategory.thunee, caller: caller);

  ThuneeCall withTrumpSuit(Suit suit) {
    return ThuneeCall(caller: caller, trumpSuit: suit);
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'trumpSuit': trumpSuit?.name,
      };

  factory ThuneeCall.fromJson(Map<String, dynamic> json) => ThuneeCall(
        caller: Seat.values.byName(json['caller'] as String),
        trumpSuit: json['trumpSuit'] != null
            ? Suit.values.byName(json['trumpSuit'] as String)
            : null,
      );

  @override
  List<Object?> get props => [...super.props, trumpSuit];

  @override
  String toString() => 'Thunee(by $caller${trumpSuit != null ? ', trump: $trumpSuit' : ''})';
}

/// Royals call (reversed card ranking)
class RoyalsCall extends CallData {
  final Suit? trumpSuit; // Set when first card is led

  const RoyalsCall({
    required Seat caller,
    this.trumpSuit,
  }) : super(category: CallCategory.royals, caller: caller);

  RoyalsCall withTrumpSuit(Suit suit) {
    return RoyalsCall(caller: caller, trumpSuit: suit);
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'trumpSuit': trumpSuit?.name,
      };

  factory RoyalsCall.fromJson(Map<String, dynamic> json) => RoyalsCall(
        caller: Seat.values.byName(json['caller'] as String),
        trumpSuit: json['trumpSuit'] != null
            ? Suit.values.byName(json['trumpSuit'] as String)
            : null,
      );

  @override
  List<Object?> get props => [...super.props, trumpSuit];

  @override
  String toString() => 'Royals(by $caller${trumpSuit != null ? ', trump: $trumpSuit' : ''})';
}

/// Blind Thunee call (with hidden cards)
class BlindThuneeCall extends CallData {
  final List<Card> hiddenCards; // Cards hidden until 4 tricks won
  final Suit? trumpSuit; // Set when first card is led

  const BlindThuneeCall({
    required Seat caller,
    required this.hiddenCards,
    this.trumpSuit,
  }) : super(category: CallCategory.blindThunee, caller: caller);

  BlindThuneeCall withTrumpSuit(Suit suit) {
    return BlindThuneeCall(
      caller: caller,
      hiddenCards: hiddenCards,
      trumpSuit: suit,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'hiddenCards': hiddenCards.map((c) => c.toJson()).toList(),
        'trumpSuit': trumpSuit?.name,
      };

  factory BlindThuneeCall.fromJson(Map<String, dynamic> json) =>
      BlindThuneeCall(
        caller: Seat.values.byName(json['caller'] as String),
        hiddenCards: (json['hiddenCards'] as List)
            .map((c) => Card.fromJson(c as String))
            .toList(),
        trumpSuit: json['trumpSuit'] != null
            ? Suit.values.byName(json['trumpSuit'] as String)
            : null,
      );

  @override
  List<Object?> get props => [...super.props, hiddenCards, trumpSuit];

  @override
  String toString() => 'BlindThunee(by $caller, ${hiddenCards.length} hidden${trumpSuit != null ? ', trump: $trumpSuit' : ''})';
}

/// Blind Royals call (with hidden cards and reversed ranking)
class BlindRoyalsCall extends CallData {
  final List<Card> hiddenCards; // Cards hidden until 4 tricks won
  final Suit? trumpSuit; // Set when first card is led

  const BlindRoyalsCall({
    required Seat caller,
    required this.hiddenCards,
    this.trumpSuit,
  }) : super(category: CallCategory.blindRoyals, caller: caller);

  BlindRoyalsCall withTrumpSuit(Suit suit) {
    return BlindRoyalsCall(
      caller: caller,
      hiddenCards: hiddenCards,
      trumpSuit: suit,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'hiddenCards': hiddenCards.map((c) => c.toJson()).toList(),
        'trumpSuit': trumpSuit?.name,
      };

  factory BlindRoyalsCall.fromJson(Map<String, dynamic> json) =>
      BlindRoyalsCall(
        caller: Seat.values.byName(json['caller'] as String),
        hiddenCards: (json['hiddenCards'] as List)
            .map((c) => Card.fromJson(c as String))
            .toList(),
        trumpSuit: json['trumpSuit'] != null
            ? Suit.values.byName(json['trumpSuit'] as String)
            : null,
      );

  @override
  List<Object?> get props => [...super.props, hiddenCards, trumpSuit];

  @override
  String toString() => 'BlindRoyals(by $caller, ${hiddenCards.length} hidden${trumpSuit != null ? ', trump: $trumpSuit' : ''})';
}

/// Jodi call (King+Queen or Jack+Queen+King combo)
class JodiCall extends CallData {
  final List<Card> cards; // The combo cards (2 or 3 cards)
  final bool isTrump; // Whether the combo is in trump suit

  const JodiCall({
    required Seat caller,
    required this.cards,
    required this.isTrump,
  }) : super(category: CallCategory.jodi, caller: caller);

  /// Returns the point value of this Jodi
  int get points {
    if (cards.length == 2) {
      // King + Queen = 20 (or 40 if trump)
      return isTrump ? 40 : 20;
    } else if (cards.length == 3) {
      // Jack + Queen + King = 30 (or 50 if trump)
      return isTrump ? 50 : 30;
    }
    return 0;
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'cards': cards.map((c) => c.toJson()).toList(),
        'isTrump': isTrump,
      };

  factory JodiCall.fromJson(Map<String, dynamic> json) => JodiCall(
        caller: Seat.values.byName(json['caller'] as String),
        cards: (json['cards'] as List)
            .map((c) => Card.fromJson(c as String))
            .toList(),
        isTrump: json['isTrump'] as bool,
      );

  @override
  List<Object?> get props => [...super.props, cards, isTrump];

  @override
  String toString() => 'Jodi(${cards.length} cards, ${isTrump ? 'trump' : 'non-trump'}, $points points by $caller)';
}

/// Double call (on last trick)
class DoubleCall extends CallData {
  const DoubleCall({
    required Seat caller,
  }) : super(category: CallCategory.double, caller: caller);

  factory DoubleCall.fromJson(Map<String, dynamic> json) => DoubleCall(
        caller: Seat.values.byName(json['caller'] as String),
      );

  @override
  String toString() => 'Double(by $caller)';
}

/// Kunuck call (on last trick, changes match target to 13)
class KunuckCall extends CallData {
  const KunuckCall({
    required Seat caller,
  }) : super(category: CallCategory.kunuck, caller: caller);

  factory KunuckCall.fromJson(Map<String, dynamic> json) => KunuckCall(
        caller: Seat.values.byName(json['caller'] as String),
      );

  @override
  String toString() => 'Kunuck(by $caller)';
}
