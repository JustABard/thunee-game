import '../models/call_type.dart';
import '../models/game_config.dart';
import '../models/player.dart';
import '../models/round_state.dart';
import '../models/card.dart';
import '../models/rank.dart';
import '../../utils/constants.dart';

/// Result of validating a call
class CallValidationResult {
  final bool isValid;
  final String? errorMessage;

  const CallValidationResult.valid() : isValid = true, errorMessage = null;
  const CallValidationResult.invalid(this.errorMessage) : isValid = false;
}

/// Validates all types of calls (bids, passes, special calls).
/// Enforces timing windows, config restrictions, and game rules.
class CallValidator {
  final GameConfig config;

  CallValidator(this.config);

  /// Validates a bid call
  CallValidationResult validateBid({
    required BidCall bid,
    required RoundState state,
  }) {
    // Must be in bidding phase
    if (state.phase != RoundPhase.bidding) {
      return const CallValidationResult.invalid('Can only bid during bidding phase');
    }

    // Bid must be in increments of 10
    if (bid.amount % BID_INCREMENT != 0) {
      return CallValidationResult.invalid('Bid must be in increments of $BID_INCREMENT');
    }

    // Bid must be at least MIN_BID
    if (bid.amount < MIN_BID) {
      return CallValidationResult.invalid('Bid must be at least $MIN_BID');
    }

    // Bid must beat current highest bid
    if (state.highestBid != null && bid.amount <= state.highestBid!.amount) {
      return CallValidationResult.invalid(
        'Bid must beat current bid of ${state.highestBid!.amount}',
      );
    }

    // Check if calling over teammate is allowed
    if (state.highestBid != null && !config.enableCallOverTeammates) {
      final highestBidderSeat = state.highestBid!.caller;
      final bidderSeat = bid.caller;

      // If same team, not allowed
      if (highestBidderSeat.teamNumber == bidderSeat.teamNumber) {
        return const CallValidationResult.invalid(
          'Cannot bid over your teammate (enableCallOverTeammates is false)',
        );
      }
    }

    return const CallValidationResult.valid();
  }

  /// Validates a pass call
  CallValidationResult validatePass({
    required PassCall pass,
    required RoundState state,
  }) {
    // Must be in bidding phase
    if (state.phase != RoundPhase.bidding) {
      return const CallValidationResult.invalid('Can only pass during bidding phase');
    }

    return const CallValidationResult.valid();
  }

  /// Validates a Thunee call
  CallValidationResult validateThunee({
    required ThuneeCall call,
    required RoundState state,
    required Player player,
  }) {
    // Must be in playing phase
    if (state.phase != RoundPhase.playing) {
      return const CallValidationResult.invalid('Thunee can only be called during play');
    }

    // Can only call after all 6 cards dealt (at start of play)
    if (state.completedTricks.isNotEmpty) {
      return const CallValidationResult.invalid('Thunee must be called before first trick');
    }

    // Player must have full hand (6 cards)
    if (player.hand.length != CARDS_PER_PLAYER) {
      return CallValidationResult.invalid(
        'Must have all $CARDS_PER_PLAYER cards to call Thunee',
      );
    }

    return const CallValidationResult.valid();
  }

  /// Validates a Royals call
  CallValidationResult validateRoyals({
    required RoyalsCall call,
    required RoundState state,
    required Player player,
  }) {
    // Must be enabled in config
    if (!config.enableRoyals) {
      return const CallValidationResult.invalid('Royals is disabled in game config');
    }

    // Must be in playing phase
    if (state.phase != RoundPhase.playing) {
      return const CallValidationResult.invalid('Royals can only be called during play');
    }

    // Can only call after all 6 cards dealt (at start of play)
    if (state.completedTricks.isNotEmpty) {
      return const CallValidationResult.invalid('Royals must be called before first trick');
    }

    // Player must have full hand (6 cards)
    if (player.hand.length != CARDS_PER_PLAYER) {
      return CallValidationResult.invalid(
        'Must have all $CARDS_PER_PLAYER cards to call Royals',
      );
    }

    return const CallValidationResult.valid();
  }

  /// Validates a Blind Thunee call
  CallValidationResult validateBlindThunee({
    required BlindThuneeCall call,
    required RoundState state,
    required Player player,
  }) {
    // Must be enabled in config
    if (!config.enableBlindThunee) {
      return const CallValidationResult.invalid('Blind Thunee is disabled in game config');
    }

    // Must be in dealing phase (after 4 cards dealt, before all 6)
    if (state.phase != RoundPhase.dealing) {
      return const CallValidationResult.invalid(
        'Blind Thunee must be called during dealing (after 4 cards)',
      );
    }

    // Player must have exactly 4 cards
    if (player.hand.length != BLIND_CALL_AFTER_CARDS) {
      return CallValidationResult.invalid(
        'Must have exactly $BLIND_CALL_AFTER_CARDS cards to call Blind Thunee',
      );
    }

    // Hidden cards must be the correct count (2 cards)
    final expectedHiddenCount = CARDS_PER_PLAYER - BLIND_CALL_AFTER_CARDS;
    if (call.hiddenCards.length != expectedHiddenCount) {
      return CallValidationResult.invalid(
        'Must hide exactly $expectedHiddenCount cards',
      );
    }

    return const CallValidationResult.valid();
  }

  /// Validates a Blind Royals call
  CallValidationResult validateBlindRoyals({
    required BlindRoyalsCall call,
    required RoundState state,
    required Player player,
  }) {
    // Must be enabled in config
    if (!config.enableBlindRoyals) {
      return const CallValidationResult.invalid('Blind Royals is disabled in game config');
    }

    // Must be in dealing phase (after 4 cards dealt, before all 6)
    if (state.phase != RoundPhase.dealing) {
      return const CallValidationResult.invalid(
        'Blind Royals must be called during dealing (after 4 cards)',
      );
    }

    // Player must have exactly 4 cards
    if (player.hand.length != BLIND_CALL_AFTER_CARDS) {
      return CallValidationResult.invalid(
        'Must have exactly $BLIND_CALL_AFTER_CARDS cards to call Blind Royals',
      );
    }

    // Hidden cards must be the correct count (2 cards)
    final expectedHiddenCount = CARDS_PER_PLAYER - BLIND_CALL_AFTER_CARDS;
    if (call.hiddenCards.length != expectedHiddenCount) {
      return CallValidationResult.invalid(
        'Must hide exactly $expectedHiddenCount cards',
      );
    }

    return const CallValidationResult.valid();
  }

  /// Validates a Jodi call
  CallValidationResult validateJodi({
    required JodiCall call,
    required RoundState state,
    required Player player,
  }) {
    // Must be enabled in config
    if (!config.enableJodi) {
      return const CallValidationResult.invalid('Jodi is disabled in game config');
    }

    // Must be during play
    if (state.phase != RoundPhase.playing) {
      return const CallValidationResult.invalid('Jodi can only be called during play');
    }

    // Check timing restriction if enabled
    if (config.enableFirstThirdOnlyJodiCalls) {
      // Jodi window opens AFTER trick 1 or 3 completes, so completedTricks.length
      // is already 1 or 3 at that point. Check the count directly.
      final completedCount = state.completedTricks.length;
      if (completedCount != 1 && completedCount != 3) {
        return const CallValidationResult.invalid(
          'Jodi can only be called after tricks 1 or 3 (enableFirstThirdOnlyJodiCalls)',
        );
      }
    }

    // Player must hold all the cards in the Jodi
    for (final card in call.cards) {
      if (!player.hasCard(card)) {
        return CallValidationResult.invalid('You do not hold ${card.shortName}');
      }
    }

    // Validate card combination
    if (call.cards.length == 2) {
      // Must be King + Queen
      final hasKing = call.cards.any((c) => c.rank == Rank.king);
      final hasQueen = call.cards.any((c) => c.rank == Rank.queen);
      if (!hasKing || !hasQueen) {
        return const CallValidationResult.invalid('2-card Jodi must be King + Queen');
      }
      // Must be same suit
      if (call.cards[0].suit != call.cards[1].suit) {
        return const CallValidationResult.invalid('Jodi cards must be same suit');
      }
    } else if (call.cards.length == 3) {
      // Must be Jack + Queen + King
      final hasJack = call.cards.any((c) => c.rank == Rank.jack);
      final hasQueen = call.cards.any((c) => c.rank == Rank.queen);
      final hasKing = call.cards.any((c) => c.rank == Rank.king);
      if (!hasJack || !hasQueen || !hasKing) {
        return const CallValidationResult.invalid('3-card Jodi must be Jack + Queen + King');
      }
      // Must be same suit
      final suit = call.cards[0].suit;
      if (!call.cards.every((c) => c.suit == suit)) {
        return const CallValidationResult.invalid('Jodi cards must be same suit');
      }
    } else {
      return CallValidationResult.invalid('Jodi must be 2 or 3 cards');
    }

    return const CallValidationResult.valid();
  }

  /// Validates a Double call
  CallValidationResult validateDouble({
    required DoubleCall call,
    required RoundState state,
  }) {
    // Must be enabled in config
    if (!config.enableDouble) {
      return const CallValidationResult.invalid('Double is disabled in game config');
    }

    // Must be during play
    if (state.phase != RoundPhase.playing) {
      return const CallValidationResult.invalid('Double can only be called during play');
    }

    // Must be on the last trick (5 tricks completed)
    if (state.completedTricks.length != 5) {
      return const CallValidationResult.invalid('Double can only be called on the last trick');
    }

    return const CallValidationResult.valid();
  }

  /// Validates a Kunuck call
  CallValidationResult validateKunuck({
    required KunuckCall call,
    required RoundState state,
  }) {
    // Must be enabled in config
    if (!config.enableKunuck) {
      return const CallValidationResult.invalid('Kunuck is disabled in game config');
    }

    // Must be during play
    if (state.phase != RoundPhase.playing) {
      return const CallValidationResult.invalid('Kunuck can only be called during play');
    }

    // Must be on the last trick (5 tricks completed)
    if (state.completedTricks.length != 5) {
      return const CallValidationResult.invalid('Kunuck can only be called on the last trick');
    }

    return const CallValidationResult.valid();
  }

  /// General validation for any call
  CallValidationResult validateCall({
    required CallData call,
    required RoundState state,
    required Player player,
  }) {
    switch (call.category) {
      case CallCategory.bid:
        return validateBid(bid: call as BidCall, state: state);
      case CallCategory.pass:
        return validatePass(pass: call as PassCall, state: state);
      case CallCategory.thunee:
        return validateThunee(call: call as ThuneeCall, state: state, player: player);
      case CallCategory.royals:
        return validateRoyals(call: call as RoyalsCall, state: state, player: player);
      case CallCategory.blindThunee:
        return validateBlindThunee(call: call as BlindThuneeCall, state: state, player: player);
      case CallCategory.blindRoyals:
        return validateBlindRoyals(call: call as BlindRoyalsCall, state: state, player: player);
      case CallCategory.jodi:
        return validateJodi(call: call as JodiCall, state: state, player: player);
      case CallCategory.double:
        return validateDouble(call: call as DoubleCall, state: state);
      case CallCategory.kunuck:
        return validateKunuck(call: call as KunuckCall, state: state);
    }
  }
}
