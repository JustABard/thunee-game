import 'dart:math';
import '../models/call_type.dart';
import '../models/card.dart';
import '../models/game_config.dart';
import '../models/player.dart';
import '../models/rank.dart';
import '../models/round_state.dart';
import '../models/suit.dart';
import 'bot_policy.dart';

/// Makes bidding and special call decisions for bots.
///
/// Uses a Hand Control Confidence (HCC) model to reason probabilistically
/// about bid levels. The bot avoids rigid/deterministic behaviour and
/// adjusts risk tolerance based on whether Call & Loss is enabled.
class CallDecisionMaker {
  final GameConfig config;
  final Random _rng;

  CallDecisionMaker(this.config, {Random? rng}) : _rng = rng ?? Random();

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Decides whether to bid and how much.
  BotDecision decideBid({
    required RoundState state,
    required Player bot,
  }) {
    // Cannot call over yourself – always pass if already highest bidder.
    if (_isAlreadyHighestBidder(state, bot)) return PassBidDecision();

    // Cannot call over a teammate (default config blocks this anyway,
    // but we short-circuit early to avoid sending an illegal bid).
    if (_isTeammateBidLeading(state, bot)) return PassBidDecision();

    final hcc = _computeHCC(bot);

    final existingBid = state.highestBid;

    if (existingBid == null) {
      return _openingBidDecision(hcc);
    } else {
      return _responseBidDecision(hcc, existingBid, bot);
    }
  }

  /// Decides whether to make a special call (Jodi etc.).
  BotDecision? decideSpecialCall({
    required RoundState state,
    required Player bot,
  }) {
    // Bots don't make special calls in this version.
    return null;
  }

  // ─── Helpers: bid eligibility ──────────────────────────────────────────────

  bool _isAlreadyHighestBidder(RoundState state, Player bot) {
    return state.highestBid?.caller == bot.seat;
  }

  bool _isTeammateBidLeading(RoundState state, Player bot) {
    if (state.highestBid == null) return false;
    if (config.enableCallOverTeammates) return false;
    return state.highestBid!.caller.teamNumber == bot.seat.teamNumber;
  }

  // ─── Hand Control Confidence (HCC) ────────────────────────────────────────

  /// Computes a confidence score [0.0, 1.0] representing how much control
  /// this hand gives over the round.
  double _computeHCC(Player bot) {
    final hand = bot.hand;
    double score = 0.0;

    // 1. Power-card contribution
    for (final card in hand) {
      score += _powerContribution(card.rank);
    }

    // 2. Best-suit concentration
    final suitCounts = _suitCounts(hand);
    final maxCount = suitCounts.values.fold(0, (m, c) => c > m ? c : m);
    score += _concentrationBonus(maxCount);

    // 3. Cross-suit coverage (reduces vulnerability to being void-cut)
    final suitsRepresented = suitCounts.values.where((c) => c > 0).length;
    score += _coverageBonus(suitsRepresented);

    // 4. Jodi potential (force multiplier, not foundation)
    score += _jodiBonus(hand, suitCounts);

    // 5. Small noise to prevent deterministic behaviour
    score += (_rng.nextDouble() - 0.5) * 0.10; // ±0.05

    return score.clamp(0.0, 1.0);
  }

  double _powerContribution(Rank rank) {
    switch (rank) {
      case Rank.jack:  return 0.20;
      case Rank.nine:  return 0.14;
      case Rank.ace:   return 0.07;
      case Rank.ten:   return 0.04;
      case Rank.king:  return 0.025;
      case Rank.queen: return 0.015;
    }
  }

  double _concentrationBonus(int maxSuitCount) {
    if (maxSuitCount >= 5) return 0.22;
    if (maxSuitCount == 4) return 0.15;
    if (maxSuitCount == 3) return 0.08;
    if (maxSuitCount == 2) return 0.03;
    return 0.0;
  }

  double _coverageBonus(int suitsRepresented) {
    if (suitsRepresented == 4) return 0.03;
    if (suitsRepresented == 3) return 0.01;
    if (suitsRepresented == 1) return -0.02; // single-suit hand is fragile
    return 0.0;
  }

  double _jodiBonus(List<Card> hand, Map<Suit, int> suitCounts) {
    double best = 0.0;
    for (final suit in Suit.values) {
      if ((suitCounts[suit] ?? 0) < 2) continue;
      final hasJ = hand.any((c) => c.suit == suit && c.rank == Rank.jack);
      final hasQ = hand.any((c) => c.suit == suit && c.rank == Rank.queen);
      final hasK = hand.any((c) => c.suit == suit && c.rank == Rank.king);
      if (hasJ && hasQ && hasK) {
        best = best < 0.10 ? 0.10 : best;
      } else if (hasK && hasQ) {
        best = best < 0.07 ? 0.07 : best;
      }
    }
    return best;
  }

  Map<Suit, int> _suitCounts(List<Card> hand) {
    final counts = <Suit, int>{};
    for (final card in hand) {
      counts[card.suit] = (counts[card.suit] ?? 0) + 1;
    }
    return counts;
  }

  // ─── Opening bid (no prior bid) ───────────────────────────────────────────

  BotDecision _openingBidDecision(double hcc) {
    if (config.enableCallAndLoss) {
      // Call & Loss: each bid is a real commitment, no free exploration.
      if (hcc < 0.48) return PassBidDecision();
      if (hcc < 0.60) {
        // Borderline – bid 10 only ~35% of the time.
        return _rng.nextDouble() < 0.35
            ? MakeBidDecision(10)
            : PassBidDecision();
      }
      if (hcc < 0.78) return MakeBidDecision(10);
      if (hcc < 0.90) {
        // Mix of 10 and 20.
        return MakeBidDecision(_rng.nextDouble() < 0.40 ? 10 : 20);
      }
      if (hcc < 0.97) return MakeBidDecision(20);
      // HCC ≥ 0.97: exceptionally strong hand.
      return MakeBidDecision(_rng.nextDouble() < 0.30 ? 30 : 20);
    } else {
      // No Call & Loss: 10 can be exploratory / defensive.
      if (hcc < 0.30) return PassBidDecision();
      if (hcc < 0.42) {
        // Weak but possible – 40% chance to open 10.
        return _rng.nextDouble() < 0.40
            ? MakeBidDecision(10)
            : PassBidDecision();
      }
      if (hcc < 0.65) return MakeBidDecision(10);
      if (hcc < 0.78) {
        // Mix of 10 and 20.
        return MakeBidDecision(_rng.nextDouble() < 0.45 ? 10 : 20);
      }
      if (hcc < 0.92) return MakeBidDecision(20);
      return MakeBidDecision(_rng.nextDouble() < 0.50 ? 20 : 30);
    }
  }

  // ─── Response bid (existing bid present) ──────────────────────────────────

  BotDecision _responseBidDecision(
      double hcc, BidCall existingBid, Player bot) {
    final currentAmount = existingBid.amount;

    // Determine minimum thresholds to overbid at each level.
    final thresholds = config.enableCallAndLoss
        ? _callAndLossThresholds()
        : _defaultThresholds();

    // Find the cheapest legal overbid amount.
    final overbidAmount = currentAmount + 10;

    // Check if we have enough confidence for this overbid level.
    final required = _requiredHcc(overbidAmount, thresholds);
    if (hcc < required) return PassBidDecision();

    // Decide the exact bid amount (don't over-escalate unnecessarily).
    return MakeBidDecision(_selectOverbidAmount(hcc, currentAmount, thresholds));
  }

  /// Returns the minimum HCC needed to bid at or above [targetAmount].
  double _requiredHcc(int targetAmount, Map<int, double> thresholds) {
    // Find the closest defined threshold at or above targetAmount.
    for (final entry in thresholds.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key))) {
      if (targetAmount <= entry.key) return entry.value;
    }
    // Very high bid – extremely high confidence needed.
    return 0.95;
  }

  /// Selects the most appropriate overbid amount given the bot's confidence.
  int _selectOverbidAmount(
      double hcc, int currentBid, Map<int, double> thresholds) {
    // Start from the minimum overbid and go up if justified.
    int amount = currentBid + 10;

    for (final nextAmount in [currentBid + 10, currentBid + 20]) {
      final threshold = _requiredHcc(nextAmount, thresholds);
      if (hcc >= threshold) {
        amount = nextAmount;
      } else {
        break;
      }
    }

    // Add small chance to bid just one level above minimum (avoid escalation).
    if (amount > currentBid + 10 && _rng.nextDouble() < 0.35) {
      amount = currentBid + 10;
    }

    return amount;
  }

  /// HCC thresholds for overbidding without Call & Loss.
  /// Key = minimum bid amount being considered, value = min HCC required.
  Map<int, double> _defaultThresholds() => {
        20: 0.50, // To bid 20 (over a 10), need HCC ≥ 0.50
        30: 0.70, // To bid 30 (over a 20), need HCC ≥ 0.70
        40: 0.85, // To bid 40+, need HCC ≥ 0.85
      };

  /// HCC thresholds for overbidding with Call & Loss enabled.
  Map<int, double> _callAndLossThresholds() => {
        20: 0.65, // Higher bar when losing gives opponents balls
        30: 0.82,
        40: 0.92,
      };
}
