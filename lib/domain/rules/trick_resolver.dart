import '../models/card.dart';
import '../models/player.dart';
import '../models/trick.dart';
import '../models/suit.dart';
import 'card_ranker.dart';

/// Result of validating a card play
class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  const ValidationResult.valid() : isValid = true, errorMessage = null;
  const ValidationResult.invalid(this.errorMessage) : isValid = false;
}

/// Resolves tricks: determines winners and validates card plays.
/// This is a CRITICAL component for correct game logic.
class TrickResolver {
  final CardRanker _ranker;

  TrickResolver(this._ranker);

  /// Validates whether a player can play a specific card.
  ///
  /// Rules:
  /// 1. Must follow suit if holding any cards of the lead suit
  /// 2. Can play any card if void in lead suit
  /// 3. First card of trick can always be played (leads the suit)
  ValidationResult validateCardPlay({
    required Card card,
    required Player player,
    required Trick trick,
  }) {
    // First card of trick - always valid
    if (trick.isEmpty) {
      return const ValidationResult.valid();
    }

    final leadSuit = trick.leadSuit!;

    // Check if player has any cards of the lead suit
    final hasLeadSuit = player.hasSuit(leadSuit);

    // If player has lead suit cards, must play one
    if (hasLeadSuit && card.suit != leadSuit) {
      return ValidationResult.invalid(
        'Must follow suit ($leadSuit). You have ${player.cardsOfSuit(leadSuit).length} cards of that suit.',
      );
    }

    // Either player doesn't have lead suit, or card matches lead suit
    return const ValidationResult.valid();
  }

  /// Determines the winner of a completed trick.
  ///
  /// Returns the Seat of the winning player.
  ///
  /// Parameters:
  /// - trick: The completed trick (must have 4 cards)
  /// - trumpSuit: The trump suit for this round
  /// - isRoyalsMode: Whether Royals ranking is active
  Seat determineWinner({
    required Trick trick,
    required Suit trumpSuit,
    bool isRoyalsMode = false,
  }) {
    if (!trick.isComplete) {
      throw StateError('Cannot determine winner of incomplete trick');
    }

    final leadSuit = trick.leadSuit!;
    final cardsInOrder = trick.cardsInOrder;

    final winningIndex = _ranker.determineWinningCardIndex(
      cards: cardsInOrder,
      trumpSuit: trumpSuit,
      leadSuit: leadSuit,
      isRoyalsMode: isRoyalsMode,
    );

    // Convert index to seat
    Seat seat = trick.leadSeat;
    for (int i = 0; i < winningIndex; i++) {
      seat = seat.next;
    }

    return seat;
  }

  /// Determines if a card "cuts" (trumps) the current winning card.
  ///
  /// Returns true if the card will win the trick when played.
  bool willCardWin({
    required Card card,
    required Trick trick,
    required Suit trumpSuit,
    bool isRoyalsMode = false,
  }) {
    if (trick.isEmpty) {
      return true; // First card always "wins" initially
    }

    // Create a temporary trick with this card added
    final tempCards = List<Card>.from(trick.cardsInOrder);
    tempCards.add(card);

    final winningIndex = _ranker.determineWinningCardIndex(
      cards: tempCards,
      trumpSuit: trumpSuit,
      leadSuit: trick.leadSuit!,
      isRoyalsMode: isRoyalsMode,
    );

    // Check if the winning card is the one we just added
    return winningIndex == tempCards.length - 1;
  }

  /// Returns the currently winning card in a trick.
  /// Returns null if trick is empty.
  Card? getCurrentWinningCard({
    required Trick trick,
    required Suit trumpSuit,
    bool isRoyalsMode = false,
  }) {
    if (trick.isEmpty) return null;

    final cards = trick.cardsInOrder;
    final winningIndex = _ranker.determineWinningCardIndex(
      cards: cards,
      trumpSuit: trumpSuit,
      leadSuit: trick.leadSuit!,
      isRoyalsMode: isRoyalsMode,
    );

    return cards[winningIndex];
  }

  /// Returns the seat currently winning the trick.
  /// Returns null if trick is empty.
  Seat? getCurrentWinningSeat({
    required Trick trick,
    required Suit trumpSuit,
    bool isRoyalsMode = false,
  }) {
    if (trick.isEmpty) return null;

    final cards = trick.cardsInOrder;
    final winningIndex = _ranker.determineWinningCardIndex(
      cards: cards,
      trumpSuit: trumpSuit,
      leadSuit: trick.leadSuit!,
      isRoyalsMode: isRoyalsMode,
    );

    Seat seat = trick.leadSeat;
    for (int i = 0; i < winningIndex; i++) {
      seat = seat.next;
    }

    return seat;
  }

  /// Checks if a card is trump
  bool isTrump(Card card, Suit trumpSuit) {
    return card.suit == trumpSuit;
  }

  /// Checks if a card matches the lead suit
  bool isLeadSuit(Card card, Suit leadSuit) {
    return card.suit == leadSuit;
  }

  /// Returns all legal cards a player can play for the current trick.
  List<Card> getLegalCards({
    required Player player,
    required Trick trick,
  }) {
    if (trick.isEmpty) {
      // Can play any card when leading
      return List.from(player.hand);
    }

    final leadSuit = trick.leadSuit!;
    final leadSuitCards = player.cardsOfSuit(leadSuit);

    // Must follow suit if possible
    if (leadSuitCards.isNotEmpty) {
      return leadSuitCards;
    }

    // If void in lead suit, can play any card
    return List.from(player.hand);
  }
}
