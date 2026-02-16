/// Represents the six ranks in a Thunee deck (24 cards total).
/// Standard order: Jack > 9 > Ace > 10 > King > Queen
/// Royals order (reversed): Queen > King > 10 > Ace > 9 > Jack
enum Rank {
  jack,
  nine,
  ace,
  ten,
  king,
  queen;

  /// Returns a display name for the rank
  String get displayName {
    switch (this) {
      case Rank.jack:
        return 'Jack';
      case Rank.nine:
        return '9';
      case Rank.ace:
        return 'Ace';
      case Rank.ten:
        return '10';
      case Rank.king:
        return 'King';
      case Rank.queen:
        return 'Queen';
    }
  }

  /// Returns a short symbol for the rank
  String get symbol {
    switch (this) {
      case Rank.jack:
        return 'J';
      case Rank.nine:
        return '9';
      case Rank.ace:
        return 'A';
      case Rank.ten:
        return '10';
      case Rank.king:
        return 'K';
      case Rank.queen:
        return 'Q';
    }
  }

  /// Returns the point value for this rank
  /// Jack=30, 9=20, Ace=11, 10=10, King=3, Queen=2
  int get points {
    switch (this) {
      case Rank.jack:
        return 30;
      case Rank.nine:
        return 20;
      case Rank.ace:
        return 11;
      case Rank.ten:
        return 10;
      case Rank.king:
        return 3;
      case Rank.queen:
        return 2;
    }
  }

  /// Returns the standard ranking (higher is better)
  /// Jack=6, 9=5, Ace=4, 10=3, King=2, Queen=1
  int get standardRanking {
    switch (this) {
      case Rank.jack:
        return 6;
      case Rank.nine:
        return 5;
      case Rank.ace:
        return 4;
      case Rank.ten:
        return 3;
      case Rank.king:
        return 2;
      case Rank.queen:
        return 1;
    }
  }

  /// Returns the Royals ranking (higher is better, reversed order)
  /// Queen=6, King=5, 10=4, Ace=3, 9=2, Jack=1
  int get royalsRanking {
    switch (this) {
      case Rank.queen:
        return 6;
      case Rank.king:
        return 5;
      case Rank.ten:
        return 4;
      case Rank.ace:
        return 3;
      case Rank.nine:
        return 2;
      case Rank.jack:
        return 1;
    }
  }
}
