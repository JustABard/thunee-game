import '../models/player.dart';
import '../models/round_state.dart';
import '../models/trick.dart';

/// Manages turn progression and phase transitions in a round.
class TurnManager {
  /// Determines the next player's turn after the current action.
  ///
  /// Rules:
  /// - During bidding: clockwise from current player
  /// - During play: clockwise from current player until trick complete
  /// - After trick complete: winner of trick leads next trick
  Seat getNextTurn(RoundState state) {
    switch (state.phase) {
      case RoundPhase.dealing:
        // After dealing, move to bidding with same turn
        return state.currentTurn;

      case RoundPhase.bidding:
        // Clockwise progression during bidding
        return state.currentTurn.next;

      case RoundPhase.playing:
        final currentTrick = state.currentTrick;

        if (currentTrick == null || currentTrick.isEmpty) {
          // Starting a new trick - current turn player leads
          return state.currentTurn;
        }

        if (currentTrick.isComplete) {
          // Trick is complete - winner leads next trick
          return currentTrick.winningSeat!;
        }

        // Trick in progress - next player clockwise
        return currentTrick.nextToPlay!;

      case RoundPhase.scoring:
        // No more turns during scoring
        return state.currentTurn;
    }
  }

  /// Determines the next phase after the current action.
  RoundPhase getNextPhase(RoundState state) {
    switch (state.phase) {
      case RoundPhase.dealing:
        // After dealing, move to bidding
        return RoundPhase.bidding;

      case RoundPhase.bidding:
        // Check if bidding should end
        if (_shouldEndBidding(state)) {
          return RoundPhase.playing;
        }
        return RoundPhase.bidding;

      case RoundPhase.playing:
        // Check if all tricks are complete
        if (state.allTricksComplete) {
          return RoundPhase.scoring;
        }
        return RoundPhase.playing;

      case RoundPhase.scoring:
        // Stay in scoring until round is explicitly ended
        return RoundPhase.scoring;
    }
  }

  /// Checks if bidding should end.
  ///
  /// Bidding ends when:
  /// 1. Three consecutive passes after a bid, OR
  /// 2. All four players pass (no bids made)
  bool _shouldEndBidding(RoundState state) {
    // If we have a bid and 3 consecutive passes, bidding ends
    if (state.highestBid != null && state.passCount >= 3) {
      return true;
    }

    // If all 4 players have passed with no bids, bidding ends
    // (This means the round is thrown in / redealt)
    if (state.passCount >= 4 && state.highestBid == null) {
      return true;
    }

    return false;
  }

  /// Determines who leads the first trick after bidding.
  ///
  /// Rules:
  /// - If there was a bid: the bidder leads
  /// - If all passed: dealer leads (or redeal)
  Seat getFirstTrickLeader(RoundState state) {
    if (state.highestBid != null) {
      return state.highestBid!.caller;
    }

    // All passed - return dealer (left of current turn)
    // Note: In practice, this might trigger a redeal instead
    return state.currentTurn.next.next.next; // 3 positions back = dealer
  }

  /// Checks if the current trick is complete
  bool isTrickComplete(Trick? trick) {
    return trick != null && trick.isComplete;
  }

  /// Checks if all tricks in the round are complete
  bool isRoundComplete(RoundState state) {
    return state.allTricksComplete;
  }

  /// Determines the lead seat for a new trick.
  ///
  /// For the first trick: the bid winner (or dealer if all passed)
  /// For subsequent tricks: the winner of the previous trick
  Seat getNextTrickLeader(RoundState state) {
    if (state.completedTricks.isEmpty) {
      // First trick
      return getFirstTrickLeader(state);
    }

    // Winner of last trick leads
    return state.lastCompletedTrick!.winningSeat!;
  }

  /// Checks if it's time to transition to a new phase
  bool shouldTransitionPhase(RoundState state) {
    return getNextPhase(state) != state.phase;
  }
}
