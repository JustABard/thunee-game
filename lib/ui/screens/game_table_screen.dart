import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/round_state.dart';
import '../../state/providers/game_state_provider.dart';
import '../../state/providers/ui_state_provider.dart';
import '../widgets/game_table/table_layout.dart';
import '../widgets/game_table/score_board.dart';
import '../widgets/calls/bidding_panel.dart';
import '../widgets/common/handover_screen.dart';
import '../widgets/common/bot_thinking_indicator.dart';

/// Main game table screen — full screen, landscape optimised.
class GameTableScreen extends ConsumerWidget {
  const GameTableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchState    = ref.watch(matchStateProvider);
    final roundState    = ref.watch(roundStateProvider);
    final needsHandover = ref.watch(needsHandoverProvider);
    final nextPlayerName = ref.watch(nextPlayerNameProvider);
    final handoverNotifier = ref.read(handoverVisibleProvider.notifier);
    final isBotTurn     = ref.watch(isBotTurnProvider);

    // Show handover when human player's turn starts in 2-player mode
    if (matchState != null && roundState != null) {
      final humanPlayers = matchState.players.where((p) => !p.isBot).toList();
      final currentPlayer = roundState.currentPlayer;

      if (humanPlayers.length == 2 && !currentPlayer.isBot && !needsHandover) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          handoverNotifier.showHandover();
        });
      }
    }

    if (matchState == null) {
      return Scaffold(
        body: const Center(child: Text('No game in progress')),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldQuit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Quit Game?'),
            content: const Text(
                'Are you sure you want to quit? Your progress will be lost.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Quit'),
              ),
            ],
          ),
        );
        if ((shouldQuit ?? false) && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        // No AppBar — we use full screen in landscape
        body: roundState == null
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  // ── Main layout: table + optional bidding panel ──────
                  Column(
                    children: [
                      Expanded(
                        child: TableLayout(roundState: roundState),
                      ),
                      if (roundState.phase == RoundPhase.bidding)
                        BiddingPanel(roundState: roundState),
                    ],
                  ),

                  // ── Score overlay (top-right corner) ─────────────────
                  Positioned(
                    top: 6,
                    right: 8,
                    child: ScoreBoard(matchState: matchState),
                  ),

                  // ── Back / quit button (top-left) ─────────────────────
                  Positioned(
                    top: 2,
                    left: 2,
                    child: SafeArea(
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white70, size: 20),
                        onPressed: () async {
                          final shouldQuit = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Quit Game?'),
                              content: const Text('Your progress will be lost.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: TextButton.styleFrom(
                                      foregroundColor: Colors.red),
                                  child: const Text('Quit'),
                                ),
                              ],
                            ),
                          );
                          if ((shouldQuit ?? false) && context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                    ),
                  ),

                  // ── Handover overlay (2-player mode) ─────────────────
                  if (needsHandover && nextPlayerName != null)
                    HandoverOverlay(
                      nextPlayerName: nextPlayerName,
                      onReady: () => handoverNotifier.hideHandover(),
                    ),

                  // ── Bot thinking indicator ────────────────────────────
                  BotThinkingIndicator(isVisible: isBotTurn && !needsHandover),
                ],
              ),
      ),
    );
  }
}
