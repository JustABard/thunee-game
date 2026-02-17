import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/card.dart';
import '../../domain/models/match_state.dart';
import '../../domain/models/player.dart';
import '../../domain/models/round_state.dart';
import '../../domain/services/game_engine.dart';
import '../../domain/bot/rule_based_bot.dart';
import '../../domain/bot/bot_policy.dart';

/// Manages game state and orchestrates actions
class GameStateNotifier extends StateNotifier<MatchState?> {
  final GameEngine _engine;
  final BotPolicy _botPolicy;

  GameStateNotifier(GameEngine engine, [BotPolicy? botPolicy])
      : _engine = engine,
        _botPolicy = botPolicy ?? RuleBasedBot(config: engine.config),
        super(null);

  /// Starts a new match with given players
  void startNewMatch(List<Player> players) {
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

    final result = _engine.makeBid(
      state: state!.currentRound!,
      amount: amount,
    );

    if (result.success && result.newState != null) {
      _updateRoundState(result.newState!);
      _checkBotTurn();
    }
  }

  /// Human player passes on bidding
  void passBid() {
    if (state == null || state!.currentRound == null) return;

    final result = _engine.passBid(state!.currentRound!);

    if (result.success && result.newState != null) {
      _updateRoundState(result.newState!);
      _checkBotTurn();
    }
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

      // Check if round is complete
      if (result.newState!.phase == RoundPhase.scoring) {
        _scoreRound();
      } else {
        _checkBotTurn();
      }
    }
  }

  /// Updates the round state in match state
  void _updateRoundState(RoundState newRoundState) {
    if (state == null) return;

    state = state!.copyWith(currentRound: newRoundState);
  }

  /// Checks if it's a bot's turn and executes bot action
  void _checkBotTurn() {
    if (state == null || state!.currentRound == null) return;

    final roundState = state!.currentRound!;
    final currentPlayer = roundState.currentPlayer;

    if (currentPlayer.isBot) {
      // Execute bot turn after a small delay for realism
      Future.delayed(const Duration(milliseconds: 800), () {
        _executeBotTurn();
      });
    }
  }

  /// Executes a bot's turn
  void _executeBotTurn() {
    if (state == null || state!.currentRound == null) return;

    final roundState = state!.currentRound!;
    final bot = roundState.currentPlayer;

    if (!bot.isBot) return;

    switch (roundState.phase) {
      case RoundPhase.bidding:
        _executeBotBid(bot, roundState);
        break;

      case RoundPhase.playing:
        _executeBotPlay(bot, roundState);
        break;

      default:
        break;
    }
  }

  /// Executes bot bidding decision
  void _executeBotBid(Player bot, RoundState roundState) {
    final decision = _botPolicy.decideBid(state: roundState, bot: bot);

    if (decision is MakeBidDecision) {
      final result = _engine.makeBid(
        state: roundState,
        amount: decision.amount,
      );

      if (result.success && result.newState != null) {
        _updateRoundState(result.newState!);
        _checkBotTurn();
      }
    } else if (decision is PassBidDecision) {
      final result = _engine.passBid(roundState);

      if (result.success && result.newState != null) {
        _updateRoundState(result.newState!);
        _checkBotTurn();
      }
    }
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

      // Check if round is complete
      if (result.newState!.phase == RoundPhase.scoring) {
        _scoreRound();
      } else {
        _checkBotTurn();
      }
    }
  }

  /// Scores the current round
  void _scoreRound() {
    if (state == null || state!.currentRound == null) return;

    final result = _engine.scoreRound(
      roundState: state!.currentRound!,
      matchState: state!,
    );

    if (result.success && result.newMatchState != null) {
      state = result.newMatchState!;

      // Check if match is complete
      if (!state!.isComplete) {
        // Start next round after a delay
        Future.delayed(const Duration(seconds: 2), () {
          _startNextRound();
        });
      }
    }
  }

  /// Starts the next round
  void _startNextRound() {
    if (state == null) return;

    // Rotate dealer
    final previousDealer = Seat.south; // TODO: Track actual dealer
    final newDealer = previousDealer.next;

    final result = _engine.startNewRound(state!, newDealer);

    if (result.success && result.newMatchState != null) {
      state = result.newMatchState!;
      _checkBotTurn();
    }
  }
}
