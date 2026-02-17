import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/card.dart';
import '../../domain/models/game_config.dart';
import '../../domain/models/match_state.dart';
import '../../domain/models/player.dart';
import '../../domain/models/round_state.dart';
import '../../domain/services/game_engine.dart';
import '../notifiers/game_state_notifier.dart';
import 'config_provider.dart';

/// Provider for game engine (uses persisted config)
final gameEngineProvider = Provider<GameEngine>((ref) {
  final config = ref.watch(configProvider);
  return GameEngine(config: config);
});

/// Provider for match state
final matchStateProvider = StateNotifierProvider<GameStateNotifier, MatchState?>((ref) {
  final engine = ref.watch(gameEngineProvider);
  return GameStateNotifier(engine);
});

/// Provider for current round state
final roundStateProvider = Provider<RoundState?>((ref) {
  final matchState = ref.watch(matchStateProvider);
  return matchState?.currentRound;
});

/// Provider for current player (human player in seat south)
final currentHumanPlayerProvider = Provider<Player?>((ref) {
  final roundState = ref.watch(roundStateProvider);
  if (roundState == null) return null;

  return roundState.players.firstWhere(
    (p) => p.seat == Seat.south,
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

/// True when the human (Seat.south) is the trump chooser and must now tap a card to set trump.
final isChoosingTrumpProvider = Provider<bool>((ref) {
  final roundState = ref.watch(roundStateProvider);
  if (roundState == null) return false;

  // During choosingTrump, currentTurn is set to the trump chooser
  return roundState.phase == RoundPhase.choosingTrump &&
      roundState.currentTurn == Seat.south;
});

/// Tracks whether the human dismissed the Thunee/Royals call prompt this round.
/// Resets to false whenever a new round starts (roundStateProvider changes).
final thuneePromptDismissedProvider = StateProvider<bool>((ref) => false);

/// True during the Thunee/Royals call window:
/// playing phase has started, no tricks have been played yet, and no call has been made.
final canCallThuneeProvider = Provider<bool>((ref) {
  final roundState = ref.watch(roundStateProvider);
  if (roundState == null) return false;

  // Only during playing phase before first card
  if (roundState.phase != RoundPhase.playing) return false;
  if (roundState.completedTricks.isNotEmpty) return false;
  if (roundState.currentTrick == null || !roundState.currentTrick!.isEmpty) return false;

  // Only if no Thunee/Royals call has been made yet
  if (roundState.activeThuneeCall != null) return false;

  // Only show to human if they're on the trump-making team
  if (Seat.south.teamNumber != roundState.trumpMakingTeam) return false;

  // Hide if human dismissed the prompt
  return !ref.watch(thuneePromptDismissedProvider);
});

/// True when the Jodi call window is open (notifier controls this flag)
final jodiWindowOpenProvider = Provider<bool>((ref) {
  final notifier = ref.watch(matchStateProvider.notifier);
  ref.watch(matchStateProvider);
  return notifier.jodiWindowOpen;
});

/// The round result description (null = no overlay showing)
final roundResultProvider = Provider<String?>((ref) {
  final notifier = ref.watch(matchStateProvider.notifier);
  ref.watch(matchStateProvider);
  return notifier.lastRoundResult;
});

/// Returns the available Jodi combos for the human player.
/// Each combo is a list of cards (K+Q or J+Q+K same suit).
final availableJodiCombosProvider = Provider<List<List<Card>>>((ref) {
  final roundState = ref.watch(roundStateProvider);
  if (roundState == null) return [];

  final southPlayer = roundState.playerAt(Seat.south);
  return GameStateNotifier.findJodiCombos(southPlayer.hand, roundState.trumpSuit);
});
