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
