import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/call_type.dart';
import '../../domain/models/card.dart';
import '../../domain/models/match_state.dart';
import '../../domain/models/player.dart';
import '../../domain/models/rank.dart';
import '../../domain/models/round_state.dart';
import '../../domain/models/suit.dart';
import '../../domain/models/trick.dart';
import '../../domain/services/game_engine.dart';
import '../../domain/bot/rule_based_bot.dart';
import '../../domain/bot/bot_policy.dart';

/// Manages game state and orchestrates actions
class GameStateNotifier extends StateNotifier<MatchState?> {
  final GameEngine _engine;
  final BotPolicy _botPolicy;
  bool _callWindowDismissed = false;
  int _callWindowWaitCount = 0;
  bool _jodiWindowOpen = false;
  String? _lastRoundResult;

  /// Epoch counter for FCFS bidding. Incremented on each bid/pass so stale
  /// bot decisions (computed before the latest action) are discarded.
  int _biddingEpoch = 0;

  /// Tracks which seats have passed in the current bidding round.
  final Set<Seat> _passedSeats = {};

  final Random _rng = Random();

  GameStateNotifier(GameEngine engine, [BotPolicy? botPolicy])
      : _engine = engine,
        _botPolicy = botPolicy ?? RuleBasedBot(config: engine.config),
        super(null);

  /// The result description from the last scored round (null = none).
  String? get lastRoundResult => _lastRoundResult;

  /// Dismisses the round result overlay and starts the next round.
  void dismissRoundResult() {
    _lastRoundResult = null;
    // Trigger rebuild
    if (state != null) {
      state = state!.copyWith();
    }
    _startNextRound();
  }

  /// Whether the Jodi call window is currently open (for UI)
  bool get jodiWindowOpen => _jodiWindowOpen;

  /// Starts a new match with given players
  void startNewMatch(List<Player> players) {
    _biddingEpoch = 0;
    _passedSeats.clear();
    final matchState = _engine.createNewMatch(players);

    // Start first round
    final result = _engine.startNewRound(matchState, Seat.south);

    if (result.success && result.newMatchState != null) {
      state = result.newMatchState;
      _checkBotTurn();
    }
  }

  /// Human player makes a bid
  void makeBid(int amount) {
    if (state == null || state!.currentRound == null) return;
    if (_passedSeats.contains(Seat.south)) return; // already passed

    final result = _engine.makeBid(
      state: state!.currentRound!,
      amount: amount,
      bidder: Seat.south,
    );

    if (result.success && result.newState != null) {
      _biddingEpoch++;
      _passedSeats.clear(); // new bid resets all passes
      _updateRoundState(result.newState!);
      _scheduleBotBidding();
    }
  }

  /// Human player passes on bidding
  void passBid() {
    if (state == null || state!.currentRound == null) return;
    if (_passedSeats.contains(Seat.south)) return; // already passed

    final result = _engine.passBid(
      state: state!.currentRound!,
      passer: Seat.south,
    );

    if (result.success && result.newState != null) {
      _biddingEpoch++;
      _passedSeats.add(Seat.south);
      _updateRoundState(result.newState!);
      _checkBiddingDoneOrSchedule();
    }
  }

  /// Human (bid winner) selects trump by tapping a card
  void selectTrump(Card card) {
    if (state == null || state!.currentRound == null) return;

    final result = _engine.selectTrump(
      state: state!.currentRound!,
      card: card,
    );

    if (result.success && result.newState != null) {
      _updateRoundState(result.newState!);
      _checkBotTurn();
    }
  }

  /// Signals that the Thunee/Royals call window has been dismissed.
  /// Called when the user taps Skip, makes a call, or the 10-second timer fires.
  void dismissCallWindow() {
    _callWindowDismissed = true;
    _callWindowWaitCount = 0;
    // Kick bot turn in case it was waiting for the window to close
    _checkBotTurn();
  }

  /// Human player calls Thunee (must win all 6 tricks)
  /// Thunee overrides trump: caller leads first, first card's suit becomes trump.
  void callThunee() {
    if (state == null || state!.currentRound == null) return;
    final round = state!.currentRound!;
    final call = ThuneeCall(caller: Seat.south);
    final result = _engine.makeSpecialCall(state: round, call: call);
    if (result.success && result.newState != null) {
      _updateRoundState(result.newState!);
      // Caller (south) leads — it's the human's turn, no bot check needed
    }
  }

  /// Human player calls Royals (reversed card ranking, must win all 6 tricks)
  /// Royals overrides trump: caller leads first, first card's suit becomes trump.
  void callRoyals() {
    if (state == null || state!.currentRound == null) return;
    final round = state!.currentRound!;
    final call = RoyalsCall(caller: Seat.south);
    final result = _engine.makeSpecialCall(state: round, call: call);
    if (result.success && result.newState != null) {
      _updateRoundState(result.newState!);
      // Caller (south) leads — it's the human's turn, no bot check needed
    }
  }

  /// Human player calls Jodi with specific cards
  void callJodi(List<Card> cards) {
    if (state == null || state!.currentRound == null) return;
    final round = state!.currentRound!;

    final isTrump = round.trumpSuit != null &&
        cards.every((c) => c.suit == round.trumpSuit);

    final call = JodiCall(
      caller: Seat.south,
      cards: cards,
      isTrump: isTrump,
    );

    final result = _engine.makeSpecialCall(state: round, call: call);
    if (result.success && result.newState != null) {
      _updateRoundState(result.newState!);
    }
  }

  /// Dismisses the Jodi call window and continues play
  void dismissJodiWindow() {
    _jodiWindowOpen = false;
    _checkBotTurn();
  }

  /// Human player plays a card
  void playCard(Card card) {
    if (state == null || state!.currentRound == null) return;

    final result = _engine.playCard(
      state: state!.currentRound!,
      card: card,
    );

    if (result.success && result.newState != null) {
      _updateRoundState(result.newState!);
      _handlePostPlay(result.newState!);
    }
  }

  /// Handles post-play logic: trick visibility, scoring, Jodi, next turn.
  void _handlePostPlay(RoundState newState) {
    final trick = newState.currentTrick;
    final trickJustCompleted = trick != null && trick.isComplete;

    if (newState.phase == RoundPhase.scoring) {
      // Round over — show the last trick, then score
      Future.delayed(const Duration(milliseconds: 1800), () {
        try {
          _scoreRound();
        } catch (e) {
          // If scoring fails, show error as round result so game isn't stuck
          _lastRoundResult = 'Scoring error: $e';
          if (state != null) {
            state = state!.copyWith();
          }
        }
      });
    } else if (trickJustCompleted) {
      // Trick completed — keep cards visible for 1.5s, then start next trick
      Future.delayed(const Duration(milliseconds: 1500), () {
        try {
          _startNextTrick(newState);
        } catch (e) {
          // Fallback: try to continue from current state
          _checkBotTurn();
        }
      });
    } else {
      // Trick still in progress — next player's turn
      _checkBotTurn();
    }
  }

  /// Starts the next trick after the completed trick was visible for a delay.
  void _startNextTrick(RoundState rs) {
    if (state == null || state!.currentRound == null) return;

    final lastTrick = rs.completedTricks.last;
    final winner = lastTrick.winningSeat!;
    final newTrick = Trick.empty(winner);

    final nextState = rs.copyWith(
      currentTrick: newTrick,
      currentTurn: winner,
    );
    _updateRoundState(nextState);

    // Check for Jodi opportunity, then continue
    _afterTrickTransition(nextState);
  }

  /// After starting a new trick, check for Jodi window or continue to bot turn.
  void _afterTrickTransition(RoundState newState) {
    if (_shouldOpenJodiWindow(newState)) {
      // Auto-call Jodi for bots first
      _autoBotJodi(newState);
      // Then check if human has Jodi
      if (_humanHasJodiCombo(newState)) {
        _jodiWindowOpen = true;
        _updateRoundState(newState);
        Future.delayed(const Duration(seconds: 8), () {
          if (_jodiWindowOpen) {
            dismissJodiWindow();
          }
        });
        return;
      }
    }
    _checkBotTurn();
  }

  /// Returns true if we should open the Jodi window after this trick
  bool _shouldOpenJodiWindow(RoundState rs) {
    // Jodi disabled during Thunee/Royals
    if (rs.activeThuneeCall != null) return false;
    // Only after tricks 1 or 3 (index 0 or 2 in completedTricks)
    final trickCount = rs.completedTricks.length;
    if (trickCount != 1 && trickCount != 3) return false;
    // The trick just completed — check if it has a winner
    final lastTrick = rs.completedTricks.last;
    if (lastTrick.winningSeat == null) return false;
    return true;
  }

  /// Auto-call Jodi for all bot players on the winning team
  void _autoBotJodi(RoundState rs) {
    final lastTrick = rs.completedTricks.last;
    final winnerTeam = lastTrick.winningSeat!.teamNumber;

    for (final player in rs.players) {
      if (!player.isBot) continue;
      if (player.seat.teamNumber != winnerTeam) continue;

      final combos = _findJodiCombos(player.hand, rs.trumpSuit);
      for (final combo in combos) {
        final call = JodiCall(
          caller: player.seat,
          cards: combo,
          isTrump: rs.trumpSuit != null &&
              combo.every((c) => c.suit == rs.trumpSuit),
        );
        final result = _engine.makeSpecialCall(state: rs, call: call);
        if (result.success && result.newState != null) {
          rs = result.newState!;
          _updateRoundState(rs);
        }
      }
    }
  }

  /// Returns true if the human (south) has a Jodi combo and is on the winning team
  bool _humanHasJodiCombo(RoundState rs) {
    final lastTrick = rs.completedTricks.last;
    final winnerTeam = lastTrick.winningSeat!.teamNumber;
    if (Seat.south.teamNumber != winnerTeam) return false;

    final southPlayer = rs.playerAt(Seat.south);
    return _findJodiCombos(southPlayer.hand, rs.trumpSuit).isNotEmpty;
  }

  /// Finds all valid Jodi combos in a hand
  static List<List<Card>> findJodiCombos(List<Card> hand, Suit? trumpSuit) {
    return _findJodiCombosStatic(hand, trumpSuit);
  }

  List<List<Card>> _findJodiCombos(List<Card> hand, Suit? trumpSuit) {
    return _findJodiCombosStatic(hand, trumpSuit);
  }

  static List<List<Card>> _findJodiCombosStatic(
      List<Card> hand, Suit? trumpSuit) {
    final combos = <List<Card>>[];

    for (final suit in Suit.values) {
      final king = hand.where(
          (c) => c.suit == suit && c.rank == Rank.king).toList();
      final queen = hand.where(
          (c) => c.suit == suit && c.rank == Rank.queen).toList();
      final jack = hand.where(
          (c) => c.suit == suit && c.rank == Rank.jack).toList();

      if (king.isNotEmpty && queen.isNotEmpty) {
        if (jack.isNotEmpty) {
          // J+Q+K is strictly better than K+Q, so only add the 3-card combo
          combos.add([jack.first, queen.first, king.first]);
        } else {
          combos.add([king.first, queen.first]);
        }
      }
    }

    return combos;
  }

  /// Updates the round state in match state
  void _updateRoundState(RoundState newRoundState) {
    if (state == null) return;

    state = state!.copyWith(currentRound: newRoundState);
  }

  /// Checks if it's a bot's turn and executes bot action.
  /// During bidding, triggers FCFS scheduling instead of single-bot turn.
  void _checkBotTurn() {
    if (state == null || state!.currentRound == null) return;

    // Don't proceed if Jodi window is open
    if (_jodiWindowOpen) return;

    final roundState = state!.currentRound!;

    // During bidding, use FCFS scheduling (no turn order)
    if (roundState.phase == RoundPhase.bidding) {
      _scheduleBotBidding();
      return;
    }

    final currentPlayer = roundState.currentPlayer;

    if (currentPlayer.isBot) {
      // If in the Thunee/Royals call window, wait for it to close first
      // Force-dismiss after ~5s (10 retries × 500ms) as a safety net
      if (_isInCallWindow(roundState) && _callWindowWaitCount < 10) {
        _callWindowWaitCount++;
        Future.delayed(const Duration(milliseconds: 500), () {
          _checkBotTurn(); // Re-check after short delay
        });
        return;
      }
      // Reset counter and force-dismiss if we hit the limit
      if (_callWindowWaitCount >= 10) {
        _callWindowDismissed = true;
      }
      _callWindowWaitCount = 0;

      // Execute bot turn after a delay for realism
      Future.delayed(const Duration(milliseconds: 1400), () {
        _executeBotTurn();
      });
    }
  }

  /// Returns true when the Thunee/Royals call window is still open.
  /// Only blocks bots if a human (south) is on the trump-making team.
  bool _isInCallWindow(RoundState rs) {
    if (_callWindowDismissed) return false;
    if (Seat.south.teamNumber != rs.trumpMakingTeam) return false;
    return rs.phase == RoundPhase.playing &&
        rs.completedTricks.isEmpty &&
        rs.currentTrick != null &&
        rs.currentTrick!.isEmpty &&
        rs.activeThuneeCall == null;
  }

  /// Executes a bot's turn
  void _executeBotTurn() {
    if (state == null || state!.currentRound == null) return;

    final roundState = state!.currentRound!;
    final bot = roundState.currentPlayer;

    if (!bot.isBot) return;

    switch (roundState.phase) {
      case RoundPhase.bidding:
        // Bidding is handled via FCFS scheduling, not single-bot turns
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

  /// Bot selects trump — picks the suit with the most cards in hand
  void _executeBotTrumpSelection(Player bot, RoundState roundState) {
    final hand = bot.hand;
    if (hand.isEmpty) return;

    // Count cards per suit
    final suitCards = <Suit, List<Card>>{};
    for (final card in hand) {
      suitCards.putIfAbsent(card.suit, () => []).add(card);
    }

    // Pick the suit with the most cards (trump potential); ties: first found
    final bestEntry = suitCards.entries
        .reduce((a, b) => a.value.length >= b.value.length ? a : b);

    final trumpCard = bestEntry.value.first;

    final result = _engine.selectTrump(state: roundState, card: trumpCard);

    if (result.success && result.newState != null) {
      _updateRoundState(result.newState!);
      _checkBotTurn();
    }
  }

  /// Schedules all bot players to bid independently with random delays (FCFS).
  void _scheduleBotBidding() {
    if (state == null || state!.currentRound == null) return;
    final rs = state!.currentRound!;
    if (rs.phase != RoundPhase.bidding) return;

    final epoch = _biddingEpoch;

    for (final player in rs.players) {
      if (!player.isBot) continue;
      if (_passedSeats.contains(player.seat)) continue;

      final delay = 400 + _rng.nextInt(1600); // 400–2000ms
      Future.delayed(Duration(milliseconds: delay), () {
        _executeSingleBotBid(player.seat, epoch);
      });
    }
  }

  /// Executes a single bot's bid/pass decision. Discards if epoch is stale.
  void _executeSingleBotBid(Seat seat, int epoch) {
    if (state == null || state!.currentRound == null) return;
    if (_biddingEpoch != epoch) return; // stale — a new bid happened since

    final rs = state!.currentRound!;
    if (rs.phase != RoundPhase.bidding) return;
    if (_passedSeats.contains(seat)) return;

    final bot = rs.playerAt(seat);
    if (!bot.isBot) return;

    final decision = _botPolicy.decideBid(state: rs, bot: bot);

    if (decision is MakeBidDecision) {
      final result = _engine.makeBid(
        state: rs,
        amount: decision.amount,
        bidder: seat,
      );

      if (result.success && result.newState != null) {
        _biddingEpoch++;
        _passedSeats.clear(); // new bid resets all passes
        _updateRoundState(result.newState!);
        _scheduleBotBidding(); // re-schedule remaining bots
      }
    } else if (decision is PassBidDecision) {
      final result = _engine.passBid(
        state: rs,
        passer: seat,
      );

      if (result.success && result.newState != null) {
        _biddingEpoch++;
        _passedSeats.add(seat);
        _updateRoundState(result.newState!);
        _checkBiddingDoneOrSchedule();
      }
    }
  }

  /// After a pass, check if bidding is complete. If not, schedule remaining bots.
  void _checkBiddingDoneOrSchedule() {
    if (state == null || state!.currentRound == null) return;
    final rs = state!.currentRound!;

    if (rs.phase != RoundPhase.bidding) {
      // Bidding ended (engine transitioned phase) — continue to trump selection
      _checkBotTurn();
      return;
    }

    // Still bidding — schedule remaining bots
    _scheduleBotBidding();
  }

  /// Executes bot card play decision
  void _executeBotPlay(Player bot, RoundState roundState) {
    final legalCards = _engine.getLegalCards(roundState);

    if (legalCards.isEmpty) return;

    final decision = _botPolicy.decideCardPlay(
      state: roundState,
      bot: bot,
      legalCards: legalCards,
    );

    final result = _engine.playCard(
      state: roundState,
      card: decision.card,
    );

    if (result.success && result.newState != null) {
      _updateRoundState(result.newState!);
      _handlePostPlay(result.newState!);
    }
  }

  /// Scores the current round
  void _scoreRound() {
    if (state == null || state!.currentRound == null) return;

    final scoringRound = state!.currentRound!;

    final result = _engine.scoreRound(
      roundState: scoringRound,
      matchState: state!,
    );

    if (result.success && result.newMatchState != null) {
      final scored = result.newMatchState!;

      // Build result description
      final breakdown = _engine.scoringEngine.calculateRoundScore(scoringRound);
      _lastRoundResult = breakdown.description;

      // Keep the scoring round visible so the table (and last trick) stay on
      // screen. completeCurrentRound() clears currentRound to null which would
      // cause the UI to show a loading spinner.
      state = MatchState(
        config: scored.config,
        players: scored.players,
        teams: scored.teams,
        completedRounds: scored.completedRounds,
        currentRound: scoringRound, // keep visible
        isComplete: scored.isComplete,
        winningTeam: scored.winningTeam,
      );

      // Don't auto-start next round — wait for user to tap the result overlay
    }
  }

  /// Starts the next round
  void _startNextRound() {
    if (state == null) return;
    _callWindowDismissed = false;
    _callWindowWaitCount = 0;
    _jodiWindowOpen = false;
    _biddingEpoch = 0;
    _passedSeats.clear();

    // Rotate dealer from the previous round
    final previousDealer = state!.currentRound?.dealer ?? Seat.south;
    final newDealer = previousDealer.next;

    // Clear currentRound so startNewRound doesn't reject with
    // "Round already in progress" (we kept it non-null for display).
    final clearedState = MatchState(
      config: state!.config,
      players: state!.players,
      teams: state!.teams,
      completedRounds: state!.completedRounds,
      currentRound: null,
      isComplete: state!.isComplete,
      winningTeam: state!.winningTeam,
    );

    final result = _engine.startNewRound(clearedState, newDealer);

    if (result.success && result.newMatchState != null) {
      state = result.newMatchState!;
      _checkBotTurn();
    }
  }
}
