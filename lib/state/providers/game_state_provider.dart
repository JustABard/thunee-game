import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/card.dart';
import '../../domain/models/match_state.dart';
import '../../domain/models/player.dart';
import '../../domain/models/round_state.dart';
import '../../domain/services/game_engine.dart';
import '../notifiers/game_state_notifier.dart';
import '../notifiers/multiplayer_game_notifier.dart';
import 'config_provider.dart';
import 'local_seat_provider.dart';
import 'lobby_provider.dart';

/// Provider for game engine (uses persisted config)
final gameEngineProvider = Provider<GameEngine>((ref) {
  final config = ref.watch(configProvider);
  return GameEngine(config: config);
});

/// Provider for match state (local / solo / pass-and-play)
final matchStateProvider = StateNotifierProvider<GameStateNotifier, MatchState?>((ref) {
  final engine = ref.watch(gameEngineProvider);
  final localSeat = ref.watch(localSeatProvider);
  return GameStateNotifier(engine, localSeat: localSeat);
});

/// Active match state — switches between local and multiplayer based on GameMode.
final activeMatchStateProvider = Provider<MatchState?>((ref) {
  final mode = ref.watch(gameModeProvider);
  if (mode == GameMode.online) {
    return ref.watch(multiplayerMatchStateProvider);
  }
  return ref.watch(matchStateProvider);
});

/// Provider for current round state
final roundStateProvider = Provider<RoundState?>((ref) {
  final matchState = ref.watch(activeMatchStateProvider);
  return matchState?.currentRound;
});

/// Provider for current player (human player at the local seat)
final currentHumanPlayerProvider = Provider<Player?>((ref) {
  final roundState = ref.watch(roundStateProvider);
  if (roundState == null) return null;

  final localSeat = ref.watch(localSeatProvider);
  return roundState.players.firstWhere(
    (p) => p.seat == localSeat,
    orElse: () => roundState.players.first,
  );
});

/// Provider for whether it's the human player's turn
final isHumanTurnProvider = Provider<bool>((ref) {
  final roundState = ref.watch(roundStateProvider);
  if (roundState == null) return false;

  final humanPlayer = ref.watch(currentHumanPlayerProvider);
  if (humanPlayer == null) return false;

  return roundState.currentTurn == humanPlayer.seat;
});

/// Provider for legal cards the human can play
final legalCardsProvider = Provider<List<Card>>((ref) {
  final roundState = ref.watch(roundStateProvider);
  final isHumanTurn = ref.watch(isHumanTurnProvider);

  if (roundState == null || !isHumanTurn) return [];

  final engine = ref.watch(gameEngineProvider);
  return engine.getLegalCards(roundState);
});

/// True when the local human is the trump chooser and must now tap a card to set trump.
final isChoosingTrumpProvider = Provider<bool>((ref) {
  final roundState = ref.watch(roundStateProvider);
  if (roundState == null) return false;

  final localSeat = ref.watch(localSeatProvider);
  // During choosingTrump, currentTurn is set to the trump chooser
  return roundState.phase == RoundPhase.choosingTrump &&
      roundState.currentTurn == localSeat;
});

/// Tracks whether the human dismissed the Thunee/Royals call prompt this round.
/// Resets to false whenever a new round starts (roundStateProvider changes).
final thuneePromptDismissedProvider = StateProvider<bool>((ref) => false);

/// True during the Thunee/Royals call window:
/// playing phase has started, no tricks have been played yet, and no call has been made.
/// Always shown to the human player regardless of which team made trump.
final canCallThuneeProvider = Provider<bool>((ref) {
  final roundState = ref.watch(roundStateProvider);
  if (roundState == null) return false;

  // Only during playing phase before first card
  if (roundState.phase != RoundPhase.playing) return false;
  if (roundState.completedTricks.isNotEmpty) return false;
  if (roundState.currentTrick == null || !roundState.currentTrick!.isEmpty) return false;

  // Only if no Thunee/Royals call has been made yet
  if (roundState.activeThuneeCall != null) return false;

  // Hide if human dismissed the prompt
  return !ref.watch(thuneePromptDismissedProvider);
});

/// True when the Jodi call window is open (notifier controls this flag)
final jodiWindowOpenProvider = Provider<bool>((ref) {
  final mode = ref.watch(gameModeProvider);
  if (mode == GameMode.online) {
    final notifier = ref.watch(multiplayerMatchStateProvider.notifier);
    ref.watch(multiplayerMatchStateProvider);
    return notifier.jodiWindowOpen;
  }
  final notifier = ref.watch(matchStateProvider.notifier);
  ref.watch(matchStateProvider);
  return notifier.jodiWindowOpen;
});

/// The round result description (null = no overlay showing)
final roundResultProvider = Provider<String?>((ref) {
  final mode = ref.watch(gameModeProvider);
  if (mode == GameMode.online) {
    final notifier = ref.watch(multiplayerMatchStateProvider.notifier);
    ref.watch(multiplayerMatchStateProvider);
    return notifier.lastRoundResult;
  }
  final notifier = ref.watch(matchStateProvider.notifier);
  ref.watch(matchStateProvider);
  return notifier.lastRoundResult;
});

/// Returns the available Jodi combos for the human player.
/// Each combo is a list of cards (K+Q or J+Q+K same suit).
final availableJodiCombosProvider = Provider<List<List<Card>>>((ref) {
  final roundState = ref.watch(roundStateProvider);
  if (roundState == null) return [];

  final localSeat = ref.watch(localSeatProvider);
  final localPlayer = roundState.playerAt(localSeat);
  return GameStateNotifier.findJodiCombos(
      localPlayer.hand, roundState.trumpSuit, roundState.callHistory);
});

/// Multiplayer match state provider — only active when game mode is online.
final multiplayerMatchStateProvider =
    StateNotifierProvider<MultiplayerGameNotifier, MatchState?>((ref) {
  final engine = ref.watch(gameEngineProvider);
  final localSeat = ref.watch(localSeatProvider);
  final lobbyCode = ref.watch(lobbyCodeProvider);
  final playerId = ref.watch(localPlayerIdProvider);
  final isHost = ref.watch(isHostProvider);
  final gameService = ref.watch(firebaseGameServiceProvider);
  final lobbyService = ref.watch(firebaseLobbyServiceProvider);

  return MultiplayerGameNotifier(
    engine: engine,
    gameService: gameService,
    lobbyService: lobbyService,
    lobbyCode: lobbyCode ?? '',
    playerId: playerId,
    localSeat: localSeat,
    isHost: isHost,
  );
});

/// Unified dispatcher for all game actions.
/// Routes calls to the correct notifier based on current GameMode.
class GameActionsDispatcher {
  final GameStateNotifier _local;
  final MultiplayerGameNotifier _multiplayer;
  final bool _isOnline;

  GameActionsDispatcher({
    required GameStateNotifier local,
    required MultiplayerGameNotifier multiplayer,
    required bool isOnline,
  })  : _local = local,
        _multiplayer = multiplayer,
        _isOnline = isOnline;

  void makeBid(int amount) =>
      _isOnline ? _multiplayer.makeBid(amount) : _local.makeBid(amount);

  void passBid() =>
      _isOnline ? _multiplayer.passBid() : _local.passBid();

  void selectTrump(Card card) =>
      _isOnline ? _multiplayer.selectTrump(card) : _local.selectTrump(card);

  void playCard(Card card) =>
      _isOnline ? _multiplayer.playCard(card) : _local.playCard(card);

  void callThunee() =>
      _isOnline ? _multiplayer.callThunee() : _local.callThunee();

  void callRoyals() =>
      _isOnline ? _multiplayer.callRoyals() : _local.callRoyals();

  void callJodi(List<Card> cards) =>
      _isOnline ? _multiplayer.callJodi(cards) : _local.callJodi(cards);

  void dismissCallWindow() =>
      _isOnline ? _multiplayer.dismissCallWindow() : _local.dismissCallWindow();

  void dismissJodiWindow() =>
      _isOnline ? _multiplayer.dismissJodiWindow() : _local.dismissJodiWindow();

  void dismissRoundResult() =>
      _isOnline ? _multiplayer.dismissRoundResult() : _local.dismissRoundResult();
}

/// Provider for the unified game action dispatcher.
final gameActionsProvider = Provider<GameActionsDispatcher>((ref) {
  final mode = ref.watch(gameModeProvider);
  return GameActionsDispatcher(
    local: ref.read(matchStateProvider.notifier),
    multiplayer: ref.read(multiplayerMatchStateProvider.notifier),
    isOnline: mode == GameMode.online,
  );
});

/// Stream of error messages from the multiplayer notifier.
final multiplayerErrorStreamProvider = StreamProvider<String>((ref) {
  final mode = ref.watch(gameModeProvider);
  if (mode != GameMode.online) return const Stream.empty();
  return ref.watch(multiplayerMatchStateProvider.notifier).errors;
});

/// Stream of player disconnect messages from the multiplayer notifier.
final multiplayerDisconnectStreamProvider = StreamProvider<String>((ref) {
  final mode = ref.watch(gameModeProvider);
  if (mode != GameMode.online) return const Stream.empty();
  return ref.watch(multiplayerMatchStateProvider.notifier).disconnections;
});
