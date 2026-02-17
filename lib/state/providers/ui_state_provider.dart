import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/player.dart';
import 'game_state_provider.dart';

/// Provider for handover mode state (2-player pass-and-play)
class HandoverNotifier extends StateNotifier<bool> {
  HandoverNotifier() : super(false);

  void showHandover() => state = true;
  void hideHandover() => state = false;
  void toggle() => state = !state;
}

final handoverVisibleProvider = StateNotifierProvider<HandoverNotifier, bool>((ref) {
  return HandoverNotifier();
});

/// Provider that determines if handover is needed
/// Returns true if it's a human player's turn in 2-player mode and handover hasn't been dismissed
final needsHandoverProvider = Provider<bool>((ref) {
  final matchState = ref.watch(matchStateProvider);
  final roundState = ref.watch(roundStateProvider);

  if (matchState == null || roundState == null) return false;

  // Count human players
  final humanPlayers = matchState.players.where((p) => !p.isBot).toList();

  // Only show handover in 2-player mode
  if (humanPlayers.length != 2) return false;

  // Check if current turn is a human
  final currentPlayer = roundState.currentPlayer;
  if (currentPlayer.isBot) return false;

  // Check handover visibility state
  final isHandoverVisible = ref.watch(handoverVisibleProvider);

  return isHandoverVisible;
});

/// Provider for the next player name (for handover screen)
final nextPlayerNameProvider = Provider<String?>((ref) {
  final roundState = ref.watch(roundStateProvider);
  if (roundState == null) return null;

  return roundState.currentPlayer.name;
});

/// Provider to check if a specific seat should show its cards
/// In 2-player mode, only show cards for the current player after handover dismissed
final shouldShowCardsProvider = Provider.family<bool, Seat>((ref, seat) {
  final matchState = ref.watch(matchStateProvider);
  final roundState = ref.watch(roundStateProvider);
  final isHandoverVisible = ref.watch(handoverVisibleProvider);

  if (matchState == null || roundState == null) return false;

  // Count human players
  final humanPlayers = matchState.players.where((p) => !p.isBot).toList();

  // In 1-player mode, always show human's cards (seat south)
  if (humanPlayers.length == 1) {
    return seat == Seat.south;
  }

  // In 2-player mode
  if (humanPlayers.length == 2) {
    // If handover is visible, hide all cards
    if (isHandoverVisible) return false;

    // Otherwise, only show current human player's cards
    final player = roundState.playerAt(seat);
    if (player.isBot) return false;

    return roundState.currentTurn == seat;
  }

  // Default: hide
  return false;
});

/// Provider to check if a bot is currently taking their turn
final isBotTurnProvider = Provider<bool>((ref) {
  final roundState = ref.watch(roundStateProvider);
  if (roundState == null) return false;

  final currentPlayer = roundState.currentPlayer;
  return currentPlayer.isBot;
});

/// Holds the result text from the last scored round (null = no overlay).
/// NOTE: The primary roundResultProvider is in game_state_provider.dart
/// (reads from GameStateNotifier.lastRoundResult).
class RoundResultNotifier extends StateNotifier<String?> {
  RoundResultNotifier() : super(null);

  void showResult(String result) => state = result;
  void dismiss() => state = null;
}
