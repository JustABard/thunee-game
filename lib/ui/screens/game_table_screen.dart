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

/// Main game table screen
class GameTableScreen extends ConsumerWidget {
  const GameTableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchState = ref.watch(matchStateProvider);
    final roundState = ref.watch(roundStateProvider);
    final needsHandover = ref.watch(needsHandoverProvider);
    final nextPlayerName = ref.watch(nextPlayerNameProvider);
    final handoverNotifier = ref.read(handoverVisibleProvider.notifier);
    final isBotTurn = ref.watch(isBotTurnProvider);

    // Automatically show handover when human player's turn starts in 2-player mode
    if (matchState != null && roundState != null) {
      final humanPlayers = matchState.players.where((p) => !p.isBot).toList();
      final currentPlayer = roundState.currentPlayer;

      if (humanPlayers.length == 2 && !currentPlayer.isBot && !needsHandover) {
        // Show handover screen on next frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          handoverNotifier.showHandover();
        });
      }
    }

    if (matchState == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Thunee')),
        body: const Center(
          child: Text('No game in progress'),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        // Confirm quit
        final shouldQuit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Quit Game?'),
            content: const Text('Are you sure you want to quit? Your progress will be lost.'),
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

        return shouldQuit ?? false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Thunee'),
          actions: [
            // Score display
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ScoreBoard(matchState: matchState),
            ),
          ],
        ),
      body: roundState == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Main game table
                Column(
                  children: [
                    // Game table
                    Expanded(
                      child: TableLayout(roundState: roundState),
                    ),

                    // Bidding panel (shown during bidding phase)
                    if (roundState.phase == RoundPhase.bidding)
                      BiddingPanel(roundState: roundState),
                  ],
                ),

                // Handover overlay (2-player mode)
                if (needsHandover && nextPlayerName != null)
                  HandoverOverlay(
                    nextPlayerName: nextPlayerName,
                    onReady: () {
                      handoverNotifier.hideHandover();
                    },
                  ),

                // Bot thinking indicator
                BotThinkingIndicator(isVisible: isBotTurn && !needsHandover),
              ],
            ),
      ),
    );
  }
}
