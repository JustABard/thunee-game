import '../models/call_type.dart';
import '../models/player.dart';
import '../models/rank.dart';
import '../models/round_state.dart';
import '../models/suit.dart';
import '../../utils/constants.dart';
import 'bot_policy.dart';

/// Makes bidding and special call decisions for bots
class CallDecisionMaker {
  /// Decides whether to bid and how much
  BotDecision decideBid({
    required RoundState state,
    required Player bot,
  }) {
    final hand = bot.hand;

    // Count high-value cards (Jack, Nine, Ace)
    final highCards = hand.where((card) =>
        card.rank == Rank.jack ||
        card.rank == Rank.nine ||
        card.rank == Rank.ace).length;

    // Count cards in each suit to find potential trump
    final suitCounts = <Suit, int>{};
    for (final card in hand) {
      suitCounts[card.suit] = (suitCounts[card.suit] ?? 0) + 1;
    }

    final maxSuitCount = suitCounts.values.fold(0, (max, count) => count > max ? count : max);

    // Simple bidding strategy:
    // - Need at least 2 cards in a suit (potential trump)
    // - Need at least 2 high cards
    // - Bid based on hand strength

    if (maxSuitCount < 2 || highCards < 2) {
      // Weak hand - pass
      return PassBidDecision();
    }

    // Calculate bid amount based on hand strength
    int bidAmount = MIN_BID;

    // Add 10 for each high card beyond 2
    if (highCards > 2) {
      bidAmount += (highCards - 2) * BID_INCREMENT;
    }

    // Add 10 if we have 3+ cards in a suit
    if (maxSuitCount >= 3) {
      bidAmount += BID_INCREMENT;
    }

    // Check if we need to beat current bid
    if (state.highestBid != null) {
      final currentBid = state.highestBid!.amount;

      // Only bid if our calculated bid is higher and we think we can win
      if (bidAmount <= currentBid) {
        // Check if we should overbid with strong hand
        if (highCards >= 4 && maxSuitCount >= 3) {
          bidAmount = currentBid + BID_INCREMENT;
        } else {
          return PassBidDecision();
        }
      }
    }

    // Don't bid more than 50 (conservative bot)
    if (bidAmount > 50) {
      bidAmount = 50;
    }

    return MakeBidDecision(bidAmount);
  }

  /// Decides whether to make a special call
  BotDecision? decideSpecialCall({
    required RoundState state,
    required Player bot,
  }) {
    // For now, bots don't make special calls
    // This can be enhanced later to call Jodi when appropriate
    return null;
  }

  /// Checks if bot should call Jodi (future enhancement)
  bool _shouldCallJodi(Player bot, RoundState state) {
    final hand = bot.hand;
    final trumpSuit = state.trumpSuit;

    // Check for K+Q combo
    for (final suit in Suit.values) {
      final hasKing = hand.any((c) => c.suit == suit && c.rank == Rank.king);
      final hasQueen = hand.any((c) => c.suit == suit && c.rank == Rank.queen);

      if (hasKing && hasQueen) {
        // Could call Jodi, but be conservative
        // Only call if team is behind or it's trump suit
        final isTrump = suit == trumpSuit;
        if (isTrump) {
          return true;
        }
      }
    }

    return false;
  }
}
