import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/firebase_game_service.dart';
import '../../data/services/firebase_lobby_service.dart';
import '../../domain/bot/bot_policy.dart';
import '../../domain/bot/rule_based_bot.dart';
import '../../domain/models/call_type.dart';
import '../../domain/models/card.dart';
import '../../domain/models/game_action.dart';
import '../../domain/models/match_state.dart';
import '../../domain/models/player.dart';
import '../../domain/models/round_state.dart';
import '../../domain/models/trick.dart';
import '../../domain/services/game_engine.dart';
import 'bot_orchestrator.dart';

/// Multiplayer game notifier — host-authoritative model.
///
/// **Host**: Runs GameEngine locally, processes actions from Firebase queue,
/// syncs redacted state back to Firebase, manages bots.
///
/// **Client**: Watches Firebase for state updates, submits actions to queue.
class MultiplayerGameNotifier extends StateNotifier<MatchState?> {
  final GameEngine _engine;
  final FirebaseGameService _gameService;
  final FirebaseLobbyService _lobbyService;
  final String _lobbyCode;
  final String _playerId;
  final Seat _localSeat;
  final bool _isHost;

  BotOrchestrator? _botOrchestrator;
  StreamSubscription? _actionSubscription;
  StreamSubscription? _stateSubscription;
  StreamSubscription? _heartbeatSubscription;
  Timer? _heartbeatTimer;

  String? _lastRoundResult;

  MultiplayerGameNotifier({
    required GameEngine engine,
    required FirebaseGameService gameService,
    required FirebaseLobbyService lobbyService,
    required String lobbyCode,
    required String playerId,
    required Seat localSeat,
    required bool isHost,
    BotPolicy? botPolicy,
  })  : _engine = engine,
        _gameService = gameService,
        _lobbyService = lobbyService,
        _lobbyCode = lobbyCode,
        _playerId = playerId,
        _localSeat = localSeat,
        _isHost = isHost,
        super(null) {
    if (_isHost) {
      _botOrchestrator = BotOrchestrator(
        engine: _engine,
        botPolicy: botPolicy ?? RuleBasedBot(config: engine.config),
        localSeat: _localSeat,
        updateState: _updateRoundState,
        readMatchState: () => state,
        onPostPlay: _handlePostPlay,
      );
    }
  }

  String? get lastRoundResult => _lastRoundResult;
  bool get jodiWindowOpen => _botOrchestrator?.jodiWindowOpen ?? false;

  /// Host: starts the match and begins syncing.
  void startMatch(List<Player> players) {
    if (!_isHost) return;

    final matchState = _engine.createNewMatch(players);
    final result = _engine.startNewRound(matchState, Seat.south);

    if (result.success && result.newMatchState != null) {
      state = result.newMatchState;
      _syncToFirebase();
      _listenForActions();
      _startHeartbeat();
      _botOrchestrator?.checkBotTurn();
    }
  }

  /// Client: starts watching Firebase for state updates.
  void startWatching() {
    if (_isHost) return;

    _stateSubscription = _gameService
        .watchGameState(_lobbyCode, _localSeat)
        .listen((matchState) {
      state = matchState;
    });

    _startHeartbeat();
  }

  // ── Human actions ──────────────────────────────────────────────────────────

  void makeBid(int amount) {
    if (_isHost) {
      _hostMakeBid(amount);
    } else {
      _submitAction(GameActionType.bid, {'amount': amount});
    }
  }

  void passBid() {
    if (_isHost) {
      _hostPassBid();
    } else {
      _submitAction(GameActionType.pass, {});
    }
  }

  void selectTrump(Card card) {
    if (_isHost) {
      _hostSelectTrump(card);
    } else {
      _submitAction(GameActionType.selectTrump, {'card': card.toJson()});
    }
  }

  void playCard(Card card) {
    if (_isHost) {
      _hostPlayCard(card);
    } else {
      _submitAction(GameActionType.playCard, {'card': card.toJson()});
    }
  }

  void callThunee() {
    if (_isHost) {
      _hostCallThunee();
    } else {
      _submitAction(GameActionType.callThunee, {});
    }
  }

  void callRoyals() {
    if (_isHost) {
      _hostCallRoyals();
    } else {
      _submitAction(GameActionType.callRoyals, {});
    }
  }

  void callJodi(List<Card> cards) {
    if (_isHost) {
      _hostCallJodi(cards);
    } else {
      _submitAction(GameActionType.callJodi, {
        'cards': cards.map((c) => c.toJson()).toList(),
      });
    }
  }

  void dismissCallWindow() {
    if (_isHost) {
      _botOrchestrator?.callWindowDismissed = true;
      _botOrchestrator?.callWindowWaitCount = 0;
      _botOrchestrator?.checkBotTurn();
    } else {
      _submitAction(GameActionType.dismissCallWindow, {});
    }
  }

  void dismissJodiWindow() {
    if (_isHost) {
      _botOrchestrator?.jodiWindowOpen = false;
      _botOrchestrator?.checkBotTurn();
    } else {
      _submitAction(GameActionType.dismissJodiWindow, {});
    }
  }

  void dismissRoundResult() {
    _lastRoundResult = null;
    if (state != null) {
      state = state!.copyWith();
    }
    if (_isHost) {
      _startNextRound();
    } else {
      _submitAction(GameActionType.dismissRoundResult, {});
    }
  }

  // ── Host-side action processing ────────────────────────────────────────────

  void _hostMakeBid(int amount) {
    if (state?.currentRound == null) return;
    final bo = _botOrchestrator!;
    if (bo.passedSeats.contains(_localSeat)) return;

    final result = _engine.makeBid(
      state: state!.currentRound!,
      amount: amount,
      bidder: _localSeat,
    );
    if (result.success && result.newState != null) {
      bo.biddingEpoch++;
      bo.passedSeats.clear();
      _updateRoundState(result.newState!);
      _syncToFirebase();
      bo.scheduleBotBidding();
    }
  }

  void _hostPassBid() {
    if (state?.currentRound == null) return;
    final bo = _botOrchestrator!;
    if (bo.passedSeats.contains(_localSeat)) return;

    final result = _engine.passBid(
      state: state!.currentRound!,
      passer: _localSeat,
    );
    if (result.success && result.newState != null) {
      bo.biddingEpoch++;
      bo.passedSeats.add(_localSeat);
      _updateRoundState(result.newState!);
      _syncToFirebase();
      bo.checkBiddingDoneOrSchedule();
    }
  }

  void _hostSelectTrump(Card card) {
    if (state?.currentRound == null) return;
    final result = _engine.selectTrump(
      state: state!.currentRound!,
      card: card,
    );
    if (result.success && result.newState != null) {
      _updateRoundState(result.newState!);
      _syncToFirebase();
      _botOrchestrator?.checkBotTurn();
    }
  }

  void _hostPlayCard(Card card) {
    if (state?.currentRound == null) return;
    final result = _engine.playCard(
      state: state!.currentRound!,
      card: card,
    );
    if (result.success && result.newState != null) {
      _updateRoundState(result.newState!);
      _syncToFirebase();
      _handlePostPlay(result.newState!);
    }
  }

  void _hostCallThunee() {
    if (state?.currentRound == null) return;
    final call = ThuneeCall(caller: _localSeat);
    final result =
        _engine.makeSpecialCall(state: state!.currentRound!, call: call);
    if (result.success && result.newState != null) {
      _updateRoundState(result.newState!);
      _syncToFirebase();
    }
  }

  void _hostCallRoyals() {
    if (state?.currentRound == null) return;
    final call = RoyalsCall(caller: _localSeat);
    final result =
        _engine.makeSpecialCall(state: state!.currentRound!, call: call);
    if (result.success && result.newState != null) {
      _updateRoundState(result.newState!);
      _syncToFirebase();
    }
  }

  void _hostCallJodi(List<Card> cards) {
    if (state?.currentRound == null) return;
    final round = state!.currentRound!;
    final isTrump = round.trumpSuit != null &&
        cards.every((c) => c.suit == round.trumpSuit);
    final call = JodiCall(
      caller: _localSeat,
      cards: cards,
      isTrump: isTrump,
    );
    final result = _engine.makeSpecialCall(state: round, call: call);
    if (result.success && result.newState != null) {
      _updateRoundState(result.newState!);
      _syncToFirebase();
    }
  }

  /// Host: processes an action from a remote client.
  void _processRemoteAction(GameAction action) {
    if (state?.currentRound == null) return;
    final round = state!.currentRound!;

    switch (action.type) {
      case GameActionType.bid:
        final result = _engine.makeBid(
          state: round,
          amount: action.data['amount'] as int,
          bidder: action.seat,
        );
        if (result.success && result.newState != null) {
          _botOrchestrator!.biddingEpoch++;
          _botOrchestrator!.passedSeats.clear();
          _updateRoundState(result.newState!);
          _syncToFirebase();
          _botOrchestrator!.scheduleBotBidding();
        }
        break;

      case GameActionType.pass:
        final result = _engine.passBid(
          state: round,
          passer: action.seat,
        );
        if (result.success && result.newState != null) {
          _botOrchestrator!.biddingEpoch++;
          _botOrchestrator!.passedSeats.add(action.seat);
          _updateRoundState(result.newState!);
          _syncToFirebase();
          _botOrchestrator!.checkBiddingDoneOrSchedule();
        }
        break;

      case GameActionType.selectTrump:
        final card = Card.fromString(action.data['card'] as String);
        final result = _engine.selectTrump(state: round, card: card);
        if (result.success && result.newState != null) {
          _updateRoundState(result.newState!);
          _syncToFirebase();
          _botOrchestrator!.checkBotTurn();
        }
        break;

      case GameActionType.playCard:
        final card = Card.fromString(action.data['card'] as String);
        final result = _engine.playCard(state: round, card: card);
        if (result.success && result.newState != null) {
          _updateRoundState(result.newState!);
          _syncToFirebase();
          _handlePostPlay(result.newState!);
        }
        break;

      case GameActionType.callThunee:
        final call = ThuneeCall(caller: action.seat);
        final result =
            _engine.makeSpecialCall(state: round, call: call);
        if (result.success && result.newState != null) {
          _updateRoundState(result.newState!);
          _syncToFirebase();
        }
        break;

      case GameActionType.callRoyals:
        final call = RoyalsCall(caller: action.seat);
        final result =
            _engine.makeSpecialCall(state: round, call: call);
        if (result.success && result.newState != null) {
          _updateRoundState(result.newState!);
          _syncToFirebase();
        }
        break;

      case GameActionType.callJodi:
        final cards = (action.data['cards'] as List)
            .map((c) => Card.fromString(c as String))
            .toList();
        final isTrump = round.trumpSuit != null &&
            cards.every((c) => c.suit == round.trumpSuit);
        final call = JodiCall(
          caller: action.seat,
          cards: cards,
          isTrump: isTrump,
        );
        final result = _engine.makeSpecialCall(state: round, call: call);
        if (result.success && result.newState != null) {
          _updateRoundState(result.newState!);
          _syncToFirebase();
        }
        break;

      case GameActionType.dismissCallWindow:
        _botOrchestrator?.callWindowDismissed = true;
        _botOrchestrator?.callWindowWaitCount = 0;
        _botOrchestrator?.checkBotTurn();
        break;

      case GameActionType.dismissJodiWindow:
        _botOrchestrator?.jodiWindowOpen = false;
        _botOrchestrator?.checkBotTurn();
        break;

      case GameActionType.dismissRoundResult:
        // Client dismissed — host handles next round
        break;
    }
  }

  // ── Internal helpers ───────────────────────────────────────────────────────

  void _updateRoundState(RoundState newRoundState) {
    if (state == null) return;
    state = state!.copyWith(currentRound: newRoundState);
  }

  void _handlePostPlay(RoundState newState) {
    final trick = newState.currentTrick;
    final trickJustCompleted = trick != null && trick.isComplete;

    if (newState.phase == RoundPhase.scoring) {
      Future.delayed(const Duration(milliseconds: 1800), () {
        _scoreRound();
      });
    } else if (trickJustCompleted) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        _startNextTrick(newState);
      });
    } else {
      _botOrchestrator?.checkBotTurn();
    }
  }

  void _startNextTrick(RoundState rs) {
    if (state?.currentRound == null) return;
    final lastTrick = rs.completedTricks.last;
    final winner = lastTrick.winningSeat!;
    final newTrick = Trick.empty(winner);

    final nextState = rs.copyWith(
      currentTrick: newTrick,
      currentTurn: winner,
    );
    _updateRoundState(nextState);
    _syncToFirebase();

    _afterTrickTransition(nextState);
  }

  void _afterTrickTransition(RoundState newState) {
    final bo = _botOrchestrator;
    if (bo == null) return;

    if (_shouldOpenJodiWindow(newState)) {
      bo.autoBotJodi(newState);
      if (bo.humanHasJodiCombo(newState)) {
        bo.jodiWindowOpen = true;
        _updateRoundState(newState);
        _syncToFirebase();
        Future.delayed(const Duration(seconds: 8), () {
          if (bo.jodiWindowOpen) {
            dismissJodiWindow();
          }
        });
        return;
      }
    }
    bo.checkBotTurn();
  }

  bool _shouldOpenJodiWindow(RoundState rs) {
    if (rs.activeThuneeCall != null) return false;
    final trickCount = rs.completedTricks.length;
    if (trickCount != 1 && trickCount != 3) return false;
    final lastTrick = rs.completedTricks.last;
    return lastTrick.winningSeat != null;
  }

  void _scoreRound() {
    if (state?.currentRound == null) return;
    final scoringRound = state!.currentRound!;

    final result = _engine.scoreRound(
      roundState: scoringRound,
      matchState: state!,
    );

    if (result.success && result.newMatchState != null) {
      final scored = result.newMatchState!;
      final breakdown =
          _engine.scoringEngine.calculateRoundScore(scoringRound);
      _lastRoundResult = breakdown.description;

      state = MatchState(
        config: scored.config,
        players: scored.players,
        teams: scored.teams,
        completedRounds: scored.completedRounds,
        currentRound: scoringRound,
        isComplete: scored.isComplete,
        winningTeam: scored.winningTeam,
      );
      _syncToFirebase();
    }
  }

  void _startNextRound() {
    if (state == null || !_isHost) return;
    _botOrchestrator?.resetForNewRound();

    final previousDealer = state!.currentRound?.dealer ?? Seat.south;
    final newDealer = previousDealer.next;

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
      state = result.newMatchState;
      _syncToFirebase();
      _botOrchestrator?.checkBotTurn();
    }
  }

  void _submitAction(GameActionType type, Map<String, dynamic> data) {
    _gameService.submitAction(
      _lobbyCode,
      GameAction(
        type: type,
        seat: _localSeat,
        data: data,
        playerId: _playerId,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> _syncToFirebase() async {
    if (state == null || !_isHost) return;
    await _gameService.syncGameState(_lobbyCode, state!);
  }

  void _listenForActions() {
    _actionSubscription =
        _gameService.watchActions(_lobbyCode).listen((entry) {
      _processRemoteAction(entry.value);
      _gameService.removeAction(_lobbyCode, entry.key);
    });
  }

  void _startHeartbeat() {
    _lobbyService.setupDisconnectHandler(_lobbyCode, _localSeat);
    _lobbyService.writeHeartbeat(_lobbyCode, _localSeat);
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _lobbyService.writeHeartbeat(_lobbyCode, _localSeat);
    });

    if (_isHost) {
      _heartbeatSubscription =
          _lobbyService.watchHeartbeats(_lobbyCode).listen((heartbeats) {
        _checkDisconnectedPlayers(heartbeats);
      });
    }
  }

  void _checkDisconnectedPlayers(Map<Seat, int> heartbeats) {
    if (state?.currentRound == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final round = state!.currentRound!;

    for (final player in round.players) {
      if (player.isBot) continue;
      if (player.seat == _localSeat) continue; // Don't check self

      final lastBeat = heartbeats[player.seat] ?? 0;
      if (now - lastBeat > 15000) {
        // Player disconnected — mark as bot
        final updatedPlayer = player.copyWith(isBot: true);
        final updatedPlayers = round.players
            .map((p) => p.seat == player.seat ? updatedPlayer : p)
            .toList();
        _updateRoundState(round.copyWith(players: updatedPlayers));
        _syncToFirebase();
        _botOrchestrator?.checkBotTurn();
      }
    }
  }

  @override
  void dispose() {
    _actionSubscription?.cancel();
    _stateSubscription?.cancel();
    _heartbeatSubscription?.cancel();
    _heartbeatTimer?.cancel();
    super.dispose();
  }
}
