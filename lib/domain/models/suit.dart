/// Represents the four suits in a Thunee deck.
enum Suit {
  hearts,
  diamonds,
  clubs,
  spades;

  /// Returns a display name for the suit
  String get displayName {
    switch (this) {
      case Suit.hearts:
        return 'Hearts';
      case Suit.diamonds:
        return 'Diamonds';
      case Suit.clubs:
        return 'Clubs';
      case Suit.spades:
        return 'Spades';
    }
  }

  /// Returns a symbol for the suit
  String get symbol {
    switch (this) {
      case Suit.hearts:
        return '♥';
      case Suit.diamonds:
        return '♦';
      case Suit.clubs:
        return '♣';
      case Suit.spades:
        return '♠';
    }
  }

  /// Returns true if the suit is red (hearts or diamonds)
  bool get isRed => this == Suit.hearts || this == Suit.diamonds;

  /// Returns true if the suit is black (clubs or spades)
  bool get isBlack => !isRed;
}
