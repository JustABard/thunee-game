import '../models/card.dart';
import '../models/player.dart';
import '../models/round_state.dart';
import '../models/suit.dart';
import '../models/trick.dart';
import '../rules/card_ranker.dart';
import '../rules/trick_resolver.dart';

/// Selects cards for bot to play based on game state
class CardSelector {
  final CardRanker _ranker;
  final TrickResolver _resolver;

  CardSelector(this._ranker, this._resolver);

  /// Selects the best card to play from legal cards
  Card selectCard({
    required RoundState state,
    required Player bot,
    required List<Card> legalCards,
  }) {
    if (legalCards.isEmpty) {
      throw StateError('No legal cards to select from');
    }

    if (legalCards.length == 1) {
      return legalCards.first;
    }

    final trick = state.currentTrick!;

    // If leading, play strongest card (trump not yet set for first card of round)
    if (trick.isEmpty) {
      return _selectLeadCard(legalCards, state, bot);
    }

    // Trump is guaranteed to be set once the first card of the round has been played
    final trumpSuit = state.trumpSuit!;

    // If following, decide whether to win or dump
    return _selectFollowCard(
      legalCards: legalCards,
      trick: trick,
      trumpSuit: trumpSuit,
      state: state,
      bot: bot,
    );
  }

  /// Selects a card to lead with
  Card _selectLeadCard(List<Card> legalCards, RoundState state, Player bot) {
    // Check if we're in Thunee/Royals mode and bot is NOT the caller
    final thuneeCall = state.activeThuneeCall;
    if (thuneeCall != null && thuneeCall.caller != bot.seat) {
      // Try to play a strong card to catch the Thunee caller
      return _getStrongestCard(legalCards, state);
    }

    // Normal play: lead with a moderately strong card
    // Sort by standard ranking and pick upper-middle
    final sorted = _sortCardsByStrength(legalCards, state);
    final middleIndex = (sorted.length * 0.6).floor();
    return sorted[middleIndex.clamp(0, sorted.length - 1)];
  }

  /// Selects a card when following suit
  Card _selectFollowCard({
    required List<Card> legalCards,
    required Trick trick,
    required Suit trumpSuit,
    required RoundState state,
    required Player bot,
  }) {
    final leadSuit = trick.leadSuit!;
    final currentWinner = _resolver.getCurrentWinningSeat(
      trick: trick,
      trumpSuit: trumpSuit,
      isRoyalsMode: state.isRoyalsMode,
    )!;

    final currentWinnerTeam = currentWinner.teamNumber;
    final botTeam = bot.seat.teamNumber;

    // Check if partner is winning
    final partnerIsWinning = currentWinnerTeam == botTeam;

    // Check for Thunee/Royals mode - NEVER cut partner if they're the caller
    final thuneeCall = state.activeThuneeCall;
    final partnerIsThuneeCall = thuneeCall != null &&
        thuneeCall.caller.teamNumber == botTeam &&
        thuneeCall.caller != bot.seat;

    if (partnerIsThuneeCall && currentWinner == thuneeCall!.caller) {
      // Partner is Thunee caller and winning - NEVER cut them
      return _getWeakestCard(legalCards, state);
    }

    // If partner is winning, dump weakest card
    if (partnerIsWinning) {
      return _getWeakestCard(legalCards, state);
    }

    // Opponent is winning - try to win if possible
    final winningCards = legalCards.where((card) {
      return _resolver.willCardWin(
        card: card,
        trick: trick,
        trumpSuit: trumpSuit,
        isRoyalsMode: state.isRoyalsMode,
      );
    }).toList();

    if (winningCards.isNotEmpty) {
      // Win with the weakest winning card (save strong cards)
      return _getWeakestWinningCard(winningCards, state);
    }

    // Can't win - dump weakest card
    return _getWeakestCard(legalCards, state);
  }

  /// Gets the strongest card from a list
  Card _getStrongestCard(List<Card> cards, RoundState state) {
    final sorted = _sortCardsByStrength(cards, state);
    return sorted.last; // Highest strength
  }

  /// Gets the weakest card from a list
  Card _getWeakestCard(List<Card> cards, RoundState state) {
    final sorted = _sortCardsByStrength(cards, state);
    return sorted.first; // Lowest strength
  }

  /// Gets the weakest card that can still win
  Card _getWeakestWinningCard(List<Card> cards, RoundState state) {
    final sorted = _sortCardsByStrength(cards, state);
    return sorted.first; // Weakest of the winning cards
  }

  /// Sorts cards by strength (weakest first)
  List<Card> _sortCardsByStrength(List<Card> cards, RoundState state) {
    final sorted = List<Card>.from(cards);
    sorted.sort((a, b) {
      final rankingA = state.isRoyalsMode ? a.rank.royalsRanking : a.rank.standardRanking;
      final rankingB = state.isRoyalsMode ? b.rank.royalsRanking : b.rank.standardRanking;
      return rankingA.compareTo(rankingB);
    });
    return sorted;
  }
}
