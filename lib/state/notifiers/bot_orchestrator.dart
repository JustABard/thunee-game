import 'dart:math';
import '../../domain/bot/bot_policy.dart';
import '../../domain/bot/trump_selector.dart';
import '../../domain/models/call_type.dart';
import '../../domain/models/card.dart';
import '../../domain/models/match_state.dart';
import '../../domain/models/player.dart';
import '../../domain/models/rank.dart';
import '../../domain/models/round_state.dart';
import '../../domain/models/suit.dart';
import '../../domain/services/game_engine.dart';

/// Callback for state mutations — the orchestrator doesn't own state,
/// it tells the caller what to do.
typedef StateUpdater = void Function(RoundState newState);
typedef MatchStateReader = MatchState? Function();

/// Encapsulates all bot-related logic (bidding, trump selection, card play,
/// Jodi auto-calling). Extracted from GameStateNotifier so it can be reused
/// by both the local and multiplayer notifiers.
class BotOrchestrator {
  final GameEngine engine;
  final BotPolicy botPolicy;
  final Seat localSeat;
  final StateUpdater updateState;
  final MatchStateReader readMatchState;
  final VoidCallbackWithState onPostPlay;

  bool callWindowDismissed = false;
  int callWindowWaitCount = 0;
  bool jodiWindowOpen = false;
  int biddingEpoch = 0;
  final Set<Seat> passedSeats = {};
  final Random _rng = Random();

  BotOrchestrator({
    required this.engine,
    required this.botPolicy,
    required this.localSeat,
    required this.updateState,
    required this.readMatchState,
    required this.onPostPlay,
  });

  /// Resets bot state for a new round.
  void resetForNewRound() {
    callWindowDismissed = false;
    callWindowWaitCount = 0;
    jodiWindowOpen = false;
    biddingEpoch = 0;
    passedSeats.clear();
  }

  /// Checks if it's a bot's turn and executes bot action.
  void checkBotTurn() {
    final match = readMatchState();
    if (match == null || match.currentRound == null) return;
    if (jodiWindowOpen) return;

    final roundState = match.currentRound!;

    if (roundState.phase == RoundPhase.bidding) {
      scheduleBotBidding();
      return;
    }

    final currentPlayer = roundState.currentPlayer;

    if (currentPlayer.isBot) {
      if (_isInCallWindow(roundState) && callWindowWaitCount < 30) {
        callWindowWaitCount++;
        Future.delayed(const Duration(milliseconds: 500), () {
          checkBotTurn();
        });
        return;
      }
      if (callWindowWaitCount >= 30) {
        callWindowDismissed = true;
      }
      callWindowWaitCount = 0;

      Future.delayed(const Duration(milliseconds: 1400), () {
        _executeBotTurn();
      });
    }
  }

  bool _isInCallWindow(RoundState rs) {
    if (callWindowDismissed) return false;
    return rs.phase == RoundPhase.playing &&
        rs.completedTricks.isEmpty &&
        rs.currentTrick != null &&
        rs.currentTrick!.isEmpty &&
        rs.activeThuneeCall == null;
  }

  void _executeBotTurn() {
    final match = readMatchState();
    if (match == null || match.currentRound == null) return;

    final roundState = match.currentRound!;
    final bot = roundState.currentPlayer;
    if (!bot.isBot) return;

    switch (roundState.phase) {
      case RoundPhase.bidding:
        break;
      case RoundPhase.choosingTrump:
        _executeBotTrumpSelection(bot, roundState);
        break;
      case RoundPhase.playing:
        _executeBotPlay(bot, roundState);
        break;
      default:
        break;
    }
  }

  void _executeBotTrumpSelection(Player bot, RoundState roundState) {
    final hand = bot.hand;
    if (hand.isEmpty) return;

    final bestSuit = selectBestTrumpSuit(hand);
    final trumpCard = hand.firstWhere((c) => c.suit == bestSuit);
    final result = engine.selectTrump(state: roundState, card: trumpCard);

    if (result.success && result.newState != null) {
      updateState(result.newState!);
      checkBotTurn();
    }
  }

  void scheduleBotBidding() {
    final match = readMatchState();
    if (match == null || match.currentRound == null) return;
    final rs = match.currentRound!;
    if (rs.phase != RoundPhase.bidding) return;

    final epoch = biddingEpoch;

    for (final player in rs.players) {
      if (!player.isBot) continue;
      if (passedSeats.contains(player.seat)) continue;
      // Highest bidder doesn't act — they already hold the top bid
      if (rs.highestBid != null && rs.highestBid!.caller == player.seat) continue;

      final delay = 400 + _rng.nextInt(1600);
      Future.delayed(Duration(milliseconds: delay), () {
        _executeSingleBotBid(player.seat, epoch);
      });
    }
  }

  void _executeSingleBotBid(Seat seat, int epoch) {
    final match = readMatchState();
    if (match == null || match.currentRound == null) return;
    if (biddingEpoch != epoch) return;

    final rs = match.currentRound!;
    if (rs.phase != RoundPhase.bidding) return;
    if (passedSeats.contains(seat)) return;

    final bot = rs.playerAt(seat);
    if (!bot.isBot) return;

    final decision = botPolicy.decideBid(state: rs, bot: bot);

    if (decision is MakeBidDecision) {
      final result = engine.makeBid(
        state: rs,
        amount: decision.amount,
        bidder: seat,
      );
      if (result.success && result.newState != null) {
        biddingEpoch++;
        passedSeats.clear();
        updateState(result.newState!);
        scheduleBotBidding();
      }
    } else if (decision is PassBidDecision) {
      final result = engine.passBid(state: rs, passer: seat);
      if (result.success && result.newState != null) {
        biddingEpoch++;
        passedSeats.add(seat);
        updateState(result.newState!);
        checkBiddingDoneOrSchedule();
      }
    }
  }

  void checkBiddingDoneOrSchedule() {
    final match = readMatchState();
    if (match == null || match.currentRound == null) return;
    final rs = match.currentRound!;

    if (rs.phase != RoundPhase.bidding) {
      checkBotTurn();
      return;
    }
    scheduleBotBidding();
  }

  void _executeBotPlay(Player bot, RoundState roundState) {
    final legalCards = engine.getLegalCards(roundState);
    if (legalCards.isEmpty) return;

    final decision = botPolicy.decideCardPlay(
      state: roundState,
      bot: bot,
      legalCards: legalCards,
    );

    final result = engine.playCard(
      state: roundState,
      card: decision.card,
    );

    if (result.success && result.newState != null) {
      updateState(result.newState!);
      onPostPlay(result.newState!);
    }
  }

  /// Auto-call Jodi for all bot players on the winning team.
  void autoBotJodi(RoundState rs) {
    final lastTrick = rs.completedTricks.last;
    final winnerTeam = lastTrick.winningSeat!.teamNumber;

    for (final player in rs.players) {
      if (!player.isBot) continue;
      if (player.seat.teamNumber != winnerTeam) continue;

      final combos = findJodiCombos(player.hand, rs.trumpSuit);
      for (final combo in combos) {
        final call = JodiCall(
          caller: player.seat,
          cards: combo,
          isTrump: rs.trumpSuit != null &&
              combo.every((c) => c.suit == rs.trumpSuit),
        );
        final result = engine.makeSpecialCall(state: rs, call: call);
        if (result.success && result.newState != null) {
          rs = result.newState!;
          updateState(rs);
        }
      }
    }
  }

  /// Returns true if the local human has a Jodi combo and is on the winning team.
  bool humanHasJodiCombo(RoundState rs) {
    final lastTrick = rs.completedTricks.last;
    final winnerTeam = lastTrick.winningSeat!.teamNumber;
    if (localSeat.teamNumber != winnerTeam) return false;

    final localPlayer = rs.playerAt(localSeat);
    return findJodiCombos(localPlayer.hand, rs.trumpSuit).isNotEmpty;
  }

  /// Finds all valid Jodi combos in a hand.
  static List<List<Card>> findJodiCombos(List<Card> hand, Suit? trumpSuit) {
    final combos = <List<Card>>[];
    for (final suit in Suit.values) {
      final king =
          hand.where((c) => c.suit == suit && c.rank == Rank.king).toList();
      final queen =
          hand.where((c) => c.suit == suit && c.rank == Rank.queen).toList();
      final jack =
          hand.where((c) => c.suit == suit && c.rank == Rank.jack).toList();

      if (king.isNotEmpty && queen.isNotEmpty) {
        if (jack.isNotEmpty) {
          combos.add([jack.first, queen.first, king.first]);
        } else {
          combos.add([king.first, queen.first]);
        }
      }
    }
    return combos;
  }
}

typedef VoidCallbackWithState = void Function(RoundState state);
