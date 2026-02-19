import 'dart:math';

import '../models/card.dart';
import '../models/player.dart';
import '../models/rank.dart';
import '../models/round_state.dart';
import '../models/suit.dart';
import '../models/trick.dart';
import '../rules/card_ranker.dart';
import '../rules/trick_resolver.dart';
import 'game_tracker.dart';

/// Selects cards for bot to play using a priority-based engine.
///
/// Leading priorities (first non-null wins):
///   0. Random deviation (~12%)
///   1. Counter opponent Thunee
///   2. Win for Jodi (tricks 1/3)
///   3. Lead Jack (prefer non-trump, shorter suit)
///   4. Pool trump (lead J of trump to flush opponents)
///   5. Bait play (A/9 in suits where bot holds J)
///   6. Win last trick (tricks 5/6)
///   7. Lead highest remaining (guaranteed win)
///   8. Dump lowest card
///
/// Following priorities:
///   0. Random deviation (~12%)
///   1. Thunee/Royals support
///   2. Smart cut
///   3. Win or dump (core logic)
class CardSelector {
  final CardRanker _ranker;
  final TrickResolver _resolver;
  final Random _rng;

  CardSelector(this._ranker, this._resolver, [Random? rng])
      : _rng = rng ?? Random();

  /// Selects the best card to play from legal cards.
  Card selectCard({
    required RoundState state,
    required Player bot,
    required List<Card> legalCards,
  }) {
    if (legalCards.isEmpty) {
      throw StateError('No legal cards to select from');
    }
    if (legalCards.length == 1) return legalCards.first;

    final trick = state.currentTrick!;
    final tracker = GameTracker.fromState(
      completedTricks: state.completedTricks,
      currentTrick: trick,
    );

    if (trick.isEmpty) {
      return _selectLeadCard(legalCards, state, bot, tracker);
    }

    return _selectFollowCard(
      legalCards: legalCards,
      trick: trick,
      trumpSuit: state.trumpSuit!,
      state: state,
      bot: bot,
      tracker: tracker,
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  LEADING
  // ──────────────────────────────────────────────────────────────────────────

  Card _selectLeadCard(
    List<Card> legalCards,
    RoundState state,
    Player bot,
    GameTracker tracker,
  ) {
    final isCritical = state.activeThuneeCall != null ||
        state.completedTricks.length >= 4;

    // Priority 0: random deviation (~12%) — not in critical situations
    if (!isCritical) {
      final r = _maybeRandomDeviation(legalCards);
      if (r != null) return r;
    }

    // Priority 1a: support teammate's Thunee/Royals — lead weakest
    final c1a = _tryLeadThuneeSupport(legalCards, state, bot);
    if (c1a != null) return c1a;

    // Priority 1b: counter opponent Thunee
    final c1 = _tryLeadThuneeCounter(legalCards, state, bot, tracker);
    if (c1 != null) return c1;

    // Priority 2: win for Jodi on tricks 1/3
    final c2 = _tryWinForJodi(legalCards, state, bot, tracker);
    if (c2 != null) return c2;

    // Priority 3: lead Jack
    final c3 = _tryLeadJack(legalCards, state, bot, tracker);
    if (c3 != null) return c3;

    // Priority 4: pool trump
    final c4 = _tryPoolTrump(legalCards, state, bot, tracker);
    if (c4 != null) return c4;

    // Priority 5: bait with A/9 in suits where we hold Jack
    final c5 = _tryBaitPlay(legalCards, state, bot, tracker);
    if (c5 != null) return c5;

    // Priority 6: win last tricks (5/6)
    final c6 = _tryWinLastTrick(legalCards, state, bot, tracker);
    if (c6 != null) return c6;

    // Priority 7: lead guaranteed winner
    final c7 = _tryLeadHighestRemaining(legalCards, tracker);
    if (c7 != null) return c7;

    // Priority 8: dump lowest
    return _leadLowestCard(legalCards, state);
  }

  /// ~12% chance of picking a random legal card.
  Card? _maybeRandomDeviation(List<Card> legalCards) {
    if (_rng.nextDouble() < 0.12) {
      return legalCards[_rng.nextInt(legalCards.length)];
    }
    return null;
  }

  /// Teammate called Thunee/Royals → dump for caller.
  /// Thunee: lead strongest (dump points). Royals: lead weakest (avoid catching).
  Card? _tryLeadThuneeSupport(
    List<Card> legalCards,
    RoundState state,
    Player bot,
  ) {
    final thuneeCall = state.activeThuneeCall;
    if (thuneeCall == null) return null;
    // Only fire if OUR team called (and we're the partner, not the caller)
    if (thuneeCall.caller.teamNumber != bot.seat.teamNumber) return null;
    if (thuneeCall.caller == bot.seat) return null; // We ARE the caller

    return _dumpForCaller(legalCards, state);
  }

  /// Opponent called Thunee → lead strongest card to try to catch them.
  Card? _tryLeadThuneeCounter(
    List<Card> legalCards,
    RoundState state,
    Player bot,
    GameTracker tracker,
  ) {
    final thuneeCall = state.activeThuneeCall;
    if (thuneeCall == null) return null;
    if (thuneeCall.caller.teamNumber == bot.seat.teamNumber) return null;

    // Lead strongest card to catch the Thunee caller
    return _getStrongestCard(legalCards, state);
  }

  /// Tricks 1 or 3: if bot has K+Q combo, prioritize winning to enable Jodi call.
  Card? _tryWinForJodi(
    List<Card> legalCards,
    RoundState state,
    Player bot,
    GameTracker tracker,
  ) {
    final trickCount = state.completedTricks.length;
    if (trickCount != 0 && trickCount != 2) return null;
    if (state.activeThuneeCall != null) return null;

    // Check if bot has a K+Q combo in any suit
    final hand = bot.hand;
    bool hasJodi = false;
    for (final suit in Suit.values) {
      final hasK = hand.any((c) => c.suit == suit && c.rank == Rank.king);
      final hasQ = hand.any((c) => c.suit == suit && c.rank == Rank.queen);
      if (hasK && hasQ) {
        hasJodi = true;
        break;
      }
    }
    if (!hasJodi) return null;

    // Lead with a strong card to win the trick
    return _getStrongestCard(legalCards, state);
  }

  /// Lead a Jack. Prefer non-trump Jack. Prefer shorter suit (less likely to be cut).
  /// If J is already played in a suit, lead the 9 instead (now highest).
  Card? _tryLeadJack(
    List<Card> legalCards,
    RoundState state,
    Player bot,
    GameTracker tracker,
  ) {
    final trumpSuit = state.trumpSuit;

    // Find all Jacks in legal cards
    final jacks = legalCards.where((c) => c.rank == Rank.jack).toList();

    if (jacks.isNotEmpty) {
      // Prefer non-trump Jack
      final nonTrumpJacks =
          jacks.where((c) => trumpSuit == null || c.suit != trumpSuit).toList();

      if (nonTrumpJacks.isNotEmpty) {
        // Pick Jack from shortest suit (less chance opponents can follow)
        nonTrumpJacks.sort((a, b) {
          final aCount = bot.cardsOfSuit(a.suit).length;
          final bCount = bot.cardsOfSuit(b.suit).length;
          return aCount.compareTo(bCount);
        });
        return nonTrumpJacks.first;
      }

      // Only trump Jack available — return it if not pooling later
      return jacks.first;
    }

    // No Jacks in hand — check if J was played and we have the 9
    for (final card in legalCards) {
      if (card.rank == Rank.nine && tracker.jackPlayed(card.suit)) {
        // Nine is now highest in this suit
        return card;
      }
    }

    return null;
  }

  /// Lead J of trump to flush opponent trumps. Only if opponents may still have trump
  /// AND teammate isn't the only one with it.
  Card? _tryPoolTrump(
    List<Card> legalCards,
    RoundState state,
    Player bot,
    GameTracker tracker,
  ) {
    final trumpSuit = state.trumpSuit;
    if (trumpSuit == null) return null;

    // Only pool if opponents may have trump
    if (!tracker.opponentsMayHaveTrump(bot.seat, trumpSuit)) return null;
    // Don't pool if only teammate has trump (wasting partner's trump)
    if (tracker.onlyTeammateHasTrump(bot.seat, trumpSuit)) return null;

    // Find Jack of trump in legal cards
    final trumpJack = legalCards.where(
      (c) => c.suit == trumpSuit && c.rank == Rank.jack,
    );

    if (trumpJack.isNotEmpty) return trumpJack.first;

    return null;
  }

  /// Lead A or 9 in suits where bot holds the Jack — bait out opponent cuts
  /// before playing J later.
  Card? _tryBaitPlay(
    List<Card> legalCards,
    RoundState state,
    Player bot,
    GameTracker tracker,
  ) {
    final hand = bot.hand;

    for (final card in legalCards) {
      if (card.rank != Rank.ace && card.rank != Rank.nine) continue;

      // Check if we also hold the Jack of this suit
      final hasJack = hand.any(
        (c) => c.suit == card.suit && c.rank == Rank.jack,
      );
      if (!hasJack) continue;

      // Don't bait in trump suit (too risky)
      if (state.trumpSuit != null && card.suit == state.trumpSuit) continue;

      return card;
    }

    return null;
  }

  /// Tricks 5/6: play to guarantee winning the last trick.
  ///
  /// On trick 5 (penultimate): if bot holds the highest remaining trump,
  /// play a non-trump card now and save trump to guarantee trick 6.
  /// On trick 6 (last): play strongest card.
  Card? _tryWinLastTrick(
    List<Card> legalCards,
    RoundState state,
    Player bot,
    GameTracker tracker,
  ) {
    final trickCount = state.completedTricks.length;
    if (trickCount < 4) return null; // Only on tricks 5 and 6

    final trumpSuit = state.trumpSuit;

    // Trick 5 (penultimate): save highest trump for last trick
    if (trickCount == 4 && trumpSuit != null && bot.hand.length == 2) {
      final trumpCards = legalCards.where((c) => c.suit == trumpSuit).toList();
      final nonTrumpCards = legalCards.where((c) => c.suit != trumpSuit).toList();

      if (trumpCards.length == 1 && nonTrumpCards.length == 1) {
        final myTrump = trumpCards.first;
        // Check if our trump is the highest remaining trump
        final highestTrump = tracker.highestRemainingInSuit(trumpSuit);
        if (highestTrump != null && highestTrump == myTrump) {
          // We have the guaranteed last-trick winner — play non-trump now
          return nonTrumpCards.first;
        }
      }
    }

    // Trick 6 or fallback: play strongest card
    return _getStrongestCard(legalCards, state);
  }

  /// If a card is guaranteed highest remaining in its suit → lead it.
  Card? _tryLeadHighestRemaining(List<Card> legalCards, GameTracker tracker) {
    for (final card in legalCards) {
      if (tracker.isHighestRemaining(card)) {
        return card;
      }
    }
    return null;
  }

  /// Dump the lowest-ranked card.
  Card _leadLowestCard(List<Card> legalCards, RoundState state) {
    return _getWeakestCard(legalCards, state);
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  FOLLOWING
  // ──────────────────────────────────────────────────────────────────────────

  Card _selectFollowCard({
    required List<Card> legalCards,
    required Trick trick,
    required Suit trumpSuit,
    required RoundState state,
    required Player bot,
    required GameTracker tracker,
  }) {
    final isCritical = state.activeThuneeCall != null ||
        state.completedTricks.length >= 4;

    // Priority 0: random deviation (~12%) — not in critical
    if (!isCritical) {
      final r = _maybeRandomDeviation(legalCards);
      if (r != null) return r;
    }

    // Priority 1: Thunee/Royals support
    final c1 = _tryThuneeSupport(legalCards, trick, trumpSuit, state, bot);
    if (c1 != null) return c1;

    // Priority 2: smart cut
    final c2 = _trySmartCut(legalCards, trick, trumpSuit, state, bot, tracker);
    if (c2 != null) return c2;

    // Priority 3: win or dump (core logic)
    return _tryWinOrDump(legalCards, trick, trumpSuit, state, bot, tracker);
  }

  /// Thunee/Royals support: teammate called → help them win.
  /// Opponent called → try to catch them.
  Card? _tryThuneeSupport(
    List<Card> legalCards,
    Trick trick,
    Suit trumpSuit,
    RoundState state,
    Player bot,
  ) {
    final thuneeCall = state.activeThuneeCall;
    if (thuneeCall == null) return null;

    final callerTeam = thuneeCall.caller.teamNumber;
    final botTeam = bot.seat.teamNumber;

    if (callerTeam == botTeam) {
      // Teammate called Thunee/Royals — help them win
      if (thuneeCall.caller == bot.seat) {
        // Bot IS the caller — play strongest to win
        return _getStrongestCard(legalCards, state);
      }
      // Bot is partner of caller.
      // Thunee: throw strongest (dump points into caller's tricks).
      // Royals: throw weakest by standard ranking (K, Q — low value, easy to beat).
      return _dumpForCaller(legalCards, state);
    } else {
      // Opponent called Thunee/Royals — try to catch them
      // Play cards that could win the trick
      final winningCards = _getWinningCards(legalCards, trick, trumpSuit, state);
      if (winningCards.isNotEmpty) {
        // Win with weakest winning card (save strong ones for later)
        return _getWeakestCard(winningCards, state);
      }
      // Can't win — hold strong cards for later tricks
      return _getWeakestCard(legalCards, state);
    }
  }

  /// Smart cutting: when void in lead suit, decide whether to trump.
  Card? _trySmartCut(
    List<Card> legalCards,
    Trick trick,
    Suit trumpSuit,
    RoundState state,
    Player bot,
    GameTracker tracker,
  ) {
    final leadSuit = trick.leadSuit!;
    final hasLeadSuit = legalCards.any((c) => c.suit == leadSuit);

    // Only applies when void in lead suit (cutting with trump)
    if (hasLeadSuit) return null;

    final trumpCards = legalCards.where((c) => c.suit == trumpSuit).toList();
    if (trumpCards.isEmpty) return null;

    final currentWinner = _resolver.getCurrentWinningSeat(
      trick: trick,
      trumpSuit: trumpSuit,
      isRoyalsMode: state.isRoyalsMode,
    );

    // Never cut if partner is already winning
    if (currentWinner != null &&
        currentWinner.teamNumber == bot.seat.teamNumber) {
      return null; // Let win-or-dump handle it
    }

    // Check if a higher trump has already been played in this trick
    final currentWinningCard = _resolver.getCurrentWinningCard(
      trick: trick,
      trumpSuit: trumpSuit,
      isRoyalsMode: state.isRoyalsMode,
    );

    if (currentWinningCard != null && currentWinningCard.suit == trumpSuit) {
      // Higher trump already played — check if we can beat it
      final beatingTrumps = trumpCards.where((c) => _ranker.beats(
            card1: c,
            card2: currentWinningCard,
            trumpSuit: trumpSuit,
            leadSuit: leadSuit,
            isRoyalsMode: state.isRoyalsMode,
          )).toList();

      if (beatingTrumps.isEmpty) {
        // Can't beat the existing trump — don't waste a trump card
        return null; // Fall through to win-or-dump (will dump)
      }

      // Can beat it — use weakest beating trump
      return _getWeakestCard(beatingTrumps, state);
    }

    // No trump played yet — check if trick is worth cutting
    final trickPoints = trick.points;
    final isPenultimate = state.completedTricks.length >= 4;

    if (trickPoints < 15 && !isPenultimate) {
      // Low-value trick, not late game — save trumps
      return null; // Fall through to dump
    }

    // Check if opponents might have higher trump
    // Use weakest trump to cut
    trumpCards.sort((a, b) {
      final ra = state.isRoyalsMode ? a.rank.royalsRanking : a.rank.standardRanking;
      final rb = state.isRoyalsMode ? b.rank.royalsRanking : b.rank.standardRanking;
      return ra.compareTo(rb);
    });
    return trumpCards.first;
  }

  /// Core follow logic: partner winning → dump value, opponent winning → win or dump.
  Card _tryWinOrDump(
    List<Card> legalCards,
    Trick trick,
    Suit trumpSuit,
    RoundState state,
    Player bot,
    GameTracker tracker,
  ) {
    final currentWinner = _resolver.getCurrentWinningSeat(
      trick: trick,
      trumpSuit: trumpSuit,
      isRoyalsMode: state.isRoyalsMode,
    );

    final partnerIsWinning =
        currentWinner != null && currentWinner.teamNumber == bot.seat.teamNumber;

    if (partnerIsWinning) {
      // Partner winning — dump high-value cards for points
      return _smartDump(legalCards, state, bot, tracker, isPartnerWinning: true);
    }

    // Opponent winning — try to win
    final winningCards = _getWinningCards(legalCards, trick, trumpSuit, state);

    if (winningCards.isNotEmpty) {
      // Win with the weakest winning card (save strong ones)
      return _getWeakestCard(winningCards, state);
    }

    // Can't win — dump lowest
    return _smartDump(legalCards, state, bot, tracker, isPartnerWinning: false);
  }

  /// Smart dumping: when partner winning, dump high-value cards for points.
  /// When losing, dump lowest. Factor in suit-length awareness.
  Card _smartDump(
    List<Card> legalCards,
    RoundState state,
    Player bot,
    GameTracker tracker, {
    required bool isPartnerWinning,
  }) {
    if (!isPartnerWinning) {
      return _getWeakestCard(legalCards, state);
    }

    // Partner winning — dump highest-value card for points
    // But don't dump our only highest-remaining card of a suit unless
    // we also hold the second-highest (otherwise we give up future wins)
    final candidates = <Card>[];
    for (final card in legalCards) {
      if (tracker.isHighestRemaining(card)) {
        // This card could win future tricks — only dump if we also hold
        // the next-highest in this suit
        final suitCards = legalCards.where((c) => c.suit == card.suit).toList();
        if (suitCards.length < 2) continue; // Keep it for future wins
      }
      candidates.add(card);
    }

    final dumpFrom = candidates.isNotEmpty ? candidates : legalCards;

    // Sort by point value descending, dump highest value
    final sorted = List<Card>.from(dumpFrom);
    sorted.sort((a, b) => b.points.compareTo(a.points));
    return sorted.first;
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  HELPERS
  // ──────────────────────────────────────────────────────────────────────────

  /// Partner support for Thunee/Royals caller.
  ///
  /// For BOTH modes: throw the HIGHEST card of whatever suit is chosen
  /// (using the current ranking mode). This gets dangerous high cards out
  /// of the partner's hand early while the caller controls the tricks,
  /// reducing the risk of accidentally catching the caller in later tricks.
  ///
  /// Thunee: highest by standard ranking (J, 9, A thrown first).
  /// Royals: highest by royals ranking (Q, K, 10 thrown first).
  Card _dumpForCaller(List<Card> legalCards, RoundState state) {
    final isRoyals = state.isRoyalsMode;

    // Group by suit
    final bySuit = <Suit, List<Card>>{};
    for (final card in legalCards) {
      bySuit.putIfAbsent(card.suit, () => []).add(card);
    }

    // For each suit, pick the highest-ranked card (most dangerous to hold)
    final candidates = <Card>[];
    for (final cards in bySuit.values) {
      cards.sort((a, b) {
        final ra = isRoyals ? a.rank.royalsRanking : a.rank.standardRanking;
        final rb = isRoyals ? b.rank.royalsRanking : b.rank.standardRanking;
        return ra.compareTo(rb);
      });
      candidates.add(cards.last); // Highest of this suit
    }

    // Pick the overall highest across all suits (most dangerous card)
    candidates.sort((a, b) {
      final ra = isRoyals ? a.rank.royalsRanking : a.rank.standardRanking;
      final rb = isRoyals ? b.rank.royalsRanking : b.rank.standardRanking;
      return ra.compareTo(rb);
    });

    return candidates.last;
  }

  List<Card> _getWinningCards(
    List<Card> legalCards,
    Trick trick,
    Suit trumpSuit,
    RoundState state,
  ) {
    return legalCards.where((card) {
      return _resolver.willCardWin(
        card: card,
        trick: trick,
        trumpSuit: trumpSuit,
        isRoyalsMode: state.isRoyalsMode,
      );
    }).toList();
  }

  Card _getStrongestCard(List<Card> cards, RoundState state) {
    final sorted = _sortByStrength(cards, state);
    return sorted.last;
  }

  Card _getWeakestCard(List<Card> cards, RoundState state) {
    final sorted = _sortByStrength(cards, state);
    return sorted.first;
  }

  List<Card> _sortByStrength(List<Card> cards, RoundState state) {
    final sorted = List<Card>.from(cards);
    sorted.sort((a, b) {
      final ra = state.isRoyalsMode ? a.rank.royalsRanking : a.rank.standardRanking;
      final rb = state.isRoyalsMode ? b.rank.royalsRanking : b.rank.standardRanking;
      return ra.compareTo(rb);
    });
    return sorted;
  }
}
