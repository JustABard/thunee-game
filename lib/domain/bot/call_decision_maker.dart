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
/// Bid levels are gated by hard structural qualifiers FIRST,
/// then Hand Control Confidence (HCC) determines the exact level.
///
/// Qualifier rules (must meet to even consider that level):
///   Bid 10 : Jack + same-suit card  OR  any Jodi (K+Q same suit)  OR  3+ same suit
///   Bid 20 : J + 3+ same suit  OR  J+Q+K same suit  OR  4+ same suit  OR  J + any Jodi
///   Bid 30 : J + 4+ same suit  OR  J+Q+K + extra power card  OR  5+ same suit
class CallDecisionMaker {
  final GameConfig config;
  final Random _rng;

  CallDecisionMaker(this.config, {Random? rng}) : _rng = rng ?? Random();

  // ─── Public API ────────────────────────────────────────────────────────────

  BotDecision decideBid({
    required RoundState state,
    required Player bot,
  }) {
    if (_isAlreadyHighestBidder(state, bot)) return PassBidDecision();
    if (_isTeammateBidLeading(state, bot)) return PassBidDecision();

    final hand = bot.hand;
    final suitCounts = _suitCounts(hand);

    // Hard gate: if hand doesn't even qualify for a 10, always pass.
    if (!_meets10Qualifier(hand, suitCounts)) return PassBidDecision();

    final hcc = _computeHCC(hand, suitCounts);
    final maxLevel = _maxBidLevel(hand, suitCounts);

    final existingBid = state.highestBid;
    if (existingBid == null) {
      return _openingBidDecision(hcc, maxLevel);
    } else {
      return _responseBidDecision(hcc, maxLevel, existingBid);
    }
  }

  BotDecision? decideSpecialCall({
    required RoundState state,
    required Player bot,
  }) => null;

  // ─── Structural qualifiers ─────────────────────────────────────────────────

  /// Can bid 10 at all.
  /// Requires: J + same-suit card  OR  K+Q same suit  OR  3+ same suit.
  bool _meets10Qualifier(List<Card> hand, Map<Suit, int> suitCounts) {
    for (final suit in Suit.values) {
      final count = suitCounts[suit] ?? 0;
      // 3+ cards in same suit
      if (count >= 3) return true;
      // Jack present + at least 1 other card of same suit
      if (count >= 2 && hand.any((c) => c.suit == suit && c.rank == Rank.jack)) {
        return true;
      }
      // K+Q in same suit (Jodi potential)
      if (count >= 2 &&
          hand.any((c) => c.suit == suit && c.rank == Rank.king) &&
          hand.any((c) => c.suit == suit && c.rank == Rank.queen)) {
        return true;
      }
    }
    return false;
  }

  /// Can bid 20.
  /// Requires one of:
  ///   - J + 3+ cards same suit (Jack with at least 2 other cards)
  ///   - J+Q+K same suit (full Jodi + Jack)
  ///   - 4+ cards same suit
  ///   - Jack anywhere + K+Q in any suit
  bool _meets20Qualifier(List<Card> hand, Map<Suit, int> suitCounts) {
    final hasJack = hand.any((c) => c.rank == Rank.jack);

    for (final suit in Suit.values) {
      final count = suitCounts[suit] ?? 0;

      // 4+ cards same suit
      if (count >= 4) return true;

      if (count >= 2) {
        final hasK = hand.any((c) => c.suit == suit && c.rank == Rank.king);
        final hasQ = hand.any((c) => c.suit == suit && c.rank == Rank.queen);
        final hasJ = hand.any((c) => c.suit == suit && c.rank == Rank.jack);

        // J+Q+K same suit
        if (hasJ && hasQ && hasK) return true;

        // Jack in this suit + 2 others (3+ total)
        if (hasJ && count >= 3) return true;

        // Jack elsewhere + K+Q in this suit
        if (hasJack && hasK && hasQ) return true;
      }
    }
    return false;
  }

  /// Can bid 30. Called during 4-card bidding phase.
  /// Requires one of:
  ///   - J + all 4 cards same suit (J + 3 others, same suit)
  ///   - J+Q+K same suit + the 4th card is a power card (9 or A) in another suit
  bool _meets30Qualifier(List<Card> hand, Map<Suit, int> suitCounts) {
    for (final suit in Suit.values) {
      final count = suitCounts[suit] ?? 0;

      if (count >= 3) {
        final hasJ = hand.any((c) => c.suit == suit && c.rank == Rank.jack);
        final hasQ = hand.any((c) => c.suit == suit && c.rank == Rank.queen);
        final hasK = hand.any((c) => c.suit == suit && c.rank == Rank.king);

        // J + 4 cards same suit (all 4 cards in one suit, including Jack)
        if (hasJ && count >= 4) return true;

        // J+Q+K same suit + extra power card (9 or A) in another suit
        if (hasJ && hasQ && hasK) {
          final hasExtraPower = hand.any(
            (c) => c.suit != suit &&
                (c.rank == Rank.nine || c.rank == Rank.ace),
          );
          if (hasExtraPower) return true;
        }
      }
    }
    return false;
  }

  /// Returns the highest bid level (10/20/30) this hand structurally qualifies for.
  int _maxBidLevel(List<Card> hand, Map<Suit, int> suitCounts) {
    if (_meets30Qualifier(hand, suitCounts)) return 30;
    if (_meets20Qualifier(hand, suitCounts)) return 20;
    return 10;
  }

  // ─── Eligibility helpers ───────────────────────────────────────────────────

  bool _isAlreadyHighestBidder(RoundState state, Player bot) =>
      state.highestBid?.caller == bot.seat;

  bool _isTeammateBidLeading(RoundState state, Player bot) {
    if (state.highestBid == null) return false;
    if (config.enableCallOverTeammates) return false;
    return state.highestBid!.caller.teamNumber == bot.seat.teamNumber;
  }

  // ─── Hand Control Confidence (HCC) ────────────────────────────────────────

  double _computeHCC(List<Card> hand, Map<Suit, int> suitCounts) {
    double score = 0.0;

    for (final card in hand) {
      score += _powerContribution(card.rank);
    }

    final maxCount = suitCounts.values.fold(0, (m, c) => c > m ? c : m);
    score += _concentrationBonus(maxCount);

    final suitsRepresented = suitCounts.values.where((c) => c > 0).length;
    score += _coverageBonus(suitsRepresented);

    score += _jodiBonus(hand, suitCounts);

    score += (_rng.nextDouble() - 0.5) * 0.10; // ±0.05 noise
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
    if (suitsRepresented == 1) return -0.02;
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

  // ─── Opening bid decision ─────────────────────────────────────────────────

  BotDecision _openingBidDecision(double hcc, int maxLevel) {
    // Determine the ideal bid level from HCC, then cap at maxLevel.
    final ideal = _idealOpeningLevel(hcc);
    final actual = ideal.clamp(0, maxLevel);

    if (actual < 10) return PassBidDecision();
    return MakeBidDecision(actual);
  }

  int _idealOpeningLevel(double hcc) {
    if (config.enableCallAndLoss) {
      // Stricter thresholds: every bid is a real commitment.
      if (hcc < 0.52) return 0;   // Pass
      if (hcc < 0.68) return 10;
      if (hcc < 0.86) {
        // Mix 10/20 in the middle band.
        return _rng.nextDouble() < 0.45 ? 10 : 20;
      }
      if (hcc < 0.95) return 20;
      return _rng.nextDouble() < 0.35 ? 20 : 30;
    } else {
      // Default rules: 10 is exploratory, but still needs the qualifier.
      if (hcc < 0.38) return 0;   // Pass even with qualifier
      if (hcc < 0.55) return 10;
      if (hcc < 0.70) {
        // Border of 10/20.
        return _rng.nextDouble() < 0.50 ? 10 : 20;
      }
      if (hcc < 0.88) return 20;
      return _rng.nextDouble() < 0.45 ? 20 : 30;
    }
  }

  // ─── Response bid decision ────────────────────────────────────────────────

  BotDecision _responseBidDecision(
      double hcc, int maxLevel, BidCall existingBid) {
    final currentAmount = existingBid.amount;
    final overbidAmount = currentAmount + 10;

    // Structural cap: can't bid a level we don't qualify for.
    if (overbidAmount > maxLevel) return PassBidDecision();

    final thresholds = config.enableCallAndLoss
        ? _callAndLossThresholds()
        : _defaultThresholds();

    final required = _requiredHcc(overbidAmount, thresholds);
    if (hcc < required) return PassBidDecision();

    return MakeBidDecision(
        _selectOverbidAmount(hcc, currentAmount, maxLevel, thresholds));
  }

  double _requiredHcc(int targetAmount, Map<int, double> thresholds) {
    for (final entry in thresholds.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key))) {
      if (targetAmount <= entry.key) return entry.value;
    }
    return 0.95;
  }

  int _selectOverbidAmount(
      double hcc, int currentBid, int maxLevel, Map<int, double> thresholds) {
    int amount = currentBid + 10;

    for (final next in [currentBid + 10, currentBid + 20]) {
      if (next > maxLevel) break;
      final threshold = _requiredHcc(next, thresholds);
      if (hcc >= threshold) {
        amount = next;
      } else {
        break;
      }
    }

    // Occasionally stay at minimum overbid to avoid runaway escalation.
    if (amount > currentBid + 10 && _rng.nextDouble() < 0.35) {
      amount = currentBid + 10;
    }

    return amount;
  }

  // ─── Thresholds ───────────────────────────────────────────────────────────

  Map<int, double> _defaultThresholds() => {
        20: 0.55,
        30: 0.75,
        40: 0.90,
      };

  Map<int, double> _callAndLossThresholds() => {
        20: 0.68,
        30: 0.84,
        40: 0.94,
      };
}
