import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../../domain/models/call_type.dart';
import '../../domain/models/card.dart' as game_card;
import '../../domain/models/match_state.dart';
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
    final canCallThunee = ref.watch(canCallThuneeProvider);
    final jodiWindowOpen = ref.watch(jodiWindowOpenProvider);
    final jodiCombos    = ref.watch(availableJodiCombosProvider);
    final roundResult   = ref.watch(roundResultProvider);

    // Reset the Thunee prompt dismissed flag when a new round begins (playing phase, empty trick)
    ref.listen(roundStateProvider, (prev, next) {
      if (next != null &&
          next.phase == RoundPhase.playing &&
          next.completedTricks.isEmpty &&
          (next.currentTrick?.isEmpty ?? false)) {
        ref.read(thuneePromptDismissedProvider.notifier).state = false;
      }
    });

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
                  // ── Main layout: table + optional panels ─────────────
                  Column(
                    children: [
                      Expanded(
                        child: TableLayout(roundState: roundState),
                      ),
                      if (roundState.phase == RoundPhase.bidding)
                        BiddingPanel(roundState: roundState),
                      if (roundState.phase == RoundPhase.choosingTrump)
                        _TrumpChoiceBanner(isBotChoosing: isBotTurn),
                      if (canCallThunee)
                        _ThuneeCallPanel(),
                      if (jodiWindowOpen && jodiCombos.isNotEmpty)
                        _JodiCallPanel(combos: jodiCombos),
                    ],
                  ),

                  // ── Card-based score display (top-right corner) ──────
                  Positioned(
                    top: 4,
                    right: 6,
                    child: _CardScoreDisplay(matchState: matchState),
                  ),

                  // ── Round trick points (top-left, below back button) ───
                  if (roundState.phase == RoundPhase.playing ||
                      roundState.phase == RoundPhase.scoring)
                    Positioned(
                      top: 6,
                      left: 40,
                      child: _TrickPointsTracker(roundState: roundState),
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

                  // ── Round result overlay ──────────────────────────────
                  if (roundResult != null)
                    _RoundResultOverlay(
                      result: roundResult,
                      matchState: matchState,
                      onDismiss: () {
                        ref.read(matchStateProvider.notifier).dismissRoundResult();
                      },
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

/// Panel for calling Thunee or Royals before the first trick.
/// Auto-skips after 10 seconds so bots aren't blocked forever.
class _ThuneeCallPanel extends ConsumerStatefulWidget {
  const _ThuneeCallPanel();

  @override
  ConsumerState<_ThuneeCallPanel> createState() => _ThuneeCallPanelState();
}

class _ThuneeCallPanelState extends ConsumerState<_ThuneeCallPanel> {
  @override
  void initState() {
    super.initState();
    // Auto-skip after 10 seconds so bots aren't blocked
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() {
    ref.read(thuneePromptDismissedProvider.notifier).state = true;
    ref.read(matchStateProvider.notifier).dismissCallWindow();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Call:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () {
              ref.read(matchStateProvider.notifier).callThunee();
              _dismiss();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: const Text('Thunee', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              ref.read(matchStateProvider.notifier).callRoyals();
              _dismiss();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: const Text('Royals', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _dismiss,
            child: const Text('Skip', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

/// Banner shown at bottom of screen while trump is being chosen
class _TrumpChoiceBanner extends StatelessWidget {
  final bool isBotChoosing;

  const _TrumpChoiceBanner({required this.isBotChoosing});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      color: Colors.green.shade800,
      child: Center(
        child: Text(
          isBotChoosing ? 'Opponent is choosing trump...' : 'Tap any card to set trump suit',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Shows each team's trick points during the current round (top-left overlay).
class _TrickPointsTracker extends StatelessWidget {
  final RoundState roundState;

  const _TrickPointsTracker({required this.roundState});

  @override
  Widget build(BuildContext context) {
    final t0 = roundState.teams[0]; // South+North
    final t1 = roundState.teams[1]; // West+East

    // Active Thunee/Royals call
    final activeCall = roundState.activeThuneeCall;

    // Jodi calls grouped by team
    final jodiCalls = roundState.specialCalls
        .where((c) => c.category == CallCategory.jodi)
        .cast<JodiCall>()
        .toList();
    final t0Jodis = jodiCalls.where((j) => j.caller.teamNumber == 0).toList();
    final t1Jodis = jodiCalls.where((j) => j.caller.teamNumber == 1).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Active Thunee/Royals banner
          if (activeCall != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: Colors.amber.shade800.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${activeCall.category.name.toUpperCase()} by ${activeCall.caller.name}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          // Team 1 (S+N)
          _teamRow('Team 1', t0.pointsCollected, t0.tricksWon, Colors.blue.shade300, t0Jodis),
          const SizedBox(height: 4),
          // Team 2 (W+E)
          _teamRow('Team 2', t1.pointsCollected, t1.tricksWon, Colors.red.shade300, t1Jodis),
        ],
      ),
    );
  }

  Widget _teamRow(String label, int points, int tricks, Color color, List<JodiCall> jodis) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              '$label',
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 6),
            Text(
              '$points pts',
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            Text(
              '($tricks tricks)',
              style: const TextStyle(color: Colors.white54, fontSize: 9),
            ),
          ],
        ),
        // Jodi calls for this team
        for (final jodi in jodis)
          Container(
            margin: const EdgeInsets.only(left: 12, top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: jodi.isTrump
                  ? Colors.amber.shade800.withValues(alpha: 0.7)
                  : Colors.teal.shade800.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              'Jodi ${jodi.cards.map((c) => c.shortName).join("+")}${jodi.isTrump ? " \u2666" : ""}  +${jodi.points}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

/// Panel for calling Jodi after winning trick 1 or 3.
/// Shows available K+Q or J+Q+K combos. Auto-dismisses after 8 seconds.
class _JodiCallPanel extends ConsumerWidget {
  final List<List<game_card.Card>> combos;

  const _JodiCallPanel({required this.combos});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Jodi:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 12),
          ...combos.map((combo) {
            final label = combo.map((c) => c.shortName).join('+');
            final isTrump = ref.read(roundStateProvider)?.trumpSuit != null &&
                combo.every((c) => c.suit == ref.read(roundStateProvider)!.trumpSuit);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ElevatedButton(
                onPressed: () {
                  ref.read(matchStateProvider.notifier).callJodi(combo);
                  ref.read(matchStateProvider.notifier).dismissJodiWindow();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isTrump ? Colors.amber.shade700 : Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: Text(
                  '$label${isTrump ? " (T)" : ""}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            );
          }),
          TextButton(
            onPressed: () {
              ref.read(matchStateProvider.notifier).dismissJodiWindow();
            },
            child: const Text('Skip', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

/// Full-screen overlay showing round result. Tap to continue.
class _RoundResultOverlay extends StatelessWidget {
  final String result;
  final MatchState matchState;
  final VoidCallback onDismiss;

  const _RoundResultOverlay({
    required this.result,
    required this.matchState,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final t0 = matchState.teams[0];
    final t1 = matchState.teams[1];

    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        color: Colors.black87,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.symmetric(horizontal: 40),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.shade400, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Round Complete',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  result,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 16),
                // Show match score with card pairs
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ScoreColumn(label: t0.name, balls: t0.balls, color: Colors.blue),
                    _ScoreColumn(label: t1.name, balls: t1.balls, color: Colors.red),
                  ],
                ),
                const SizedBox(height: 16),
                if (matchState.isComplete)
                  Text(
                    '${matchState.winner?.name ?? "A team"} wins the match!',
                    style: TextStyle(
                      color: Colors.amber.shade300,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else
                  Text(
                    'Tap to continue',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreColumn extends StatelessWidget {
  final String label;
  final int balls;
  final Color color;

  const _ScoreColumn({required this.label, required this.balls, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        _CardScorePair(balls: balls, color: color),
        const SizedBox(height: 4),
        Text('$balls balls', style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}

/// Score display in top-right corner — shows balls as diamond strips per team.
class _CardScoreDisplay extends StatelessWidget {
  final MatchState matchState;

  const _CardScoreDisplay({required this.matchState});

  @override
  Widget build(BuildContext context) {
    final t0 = matchState.teams[0];
    final t1 = matchState.teams[1];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DiamondScoreRow(label: 'T1', balls: t0.balls, color: Colors.blue.shade300),
          const SizedBox(height: 4),
          _DiamondScoreRow(label: 'T2', balls: t1.balls, color: Colors.red.shade300),
        ],
      ),
    );
  }
}

/// Shows one team's ball score as two rows of 6 diamonds each.
/// Row 1 = balls 1–6, Row 2 = balls 7–12.
/// Filled ◆ = earned, outline ◇ = not yet.
class _DiamondScoreRow extends StatelessWidget {
  final String label;
  final int balls;
  final Color color;

  const _DiamondScoreRow({required this.label, required this.balls, required this.color});

  @override
  Widget build(BuildContext context) {
    final clamped = balls.clamp(0, 13);
    final row1Filled = math.min(clamped, 6);
    final row2Filled = math.max(clamped - 6, 0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Team label
        SizedBox(
          width: 16,
          child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
        ),
        // Two rows of 6 diamonds
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _diamondRow(row1Filled, 6, color),
            const SizedBox(height: 1),
            _diamondRow(row2Filled, 6, color),
          ],
        ),
        const SizedBox(width: 4),
        // Numeric label
        Text(
          '$clamped',
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _diamondRow(int filled, int total, Color teamColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < total; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0.5),
            child: Text(
              i < filled ? '\u25C6' : '\u25C7',
              style: TextStyle(
                color: i < filled ? teamColor : Colors.white24,
                fontSize: 8,
                height: 1,
              ),
            ),
          ),
      ],
    );
  }
}

/// Score pair for the round-result overlay (larger version).
/// Two card shapes side by side, each with 6 diamond slots.
class _CardScorePair extends StatelessWidget {
  final int balls;
  final Color color;
  final double cardH;

  const _CardScorePair({required this.balls, required this.color, this.cardH = 50});

  @override
  Widget build(BuildContext context) {
    final clamped = balls.clamp(0, 13);
    final card1Filled = math.min(clamped, 6);
    final card2Filled = math.max(clamped - 6, 0);

    final cardW = cardH * 0.67;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ScoreCard(filled: card1Filled, width: cardW, height: cardH, color: color),
        const SizedBox(width: 4),
        _ScoreCard(filled: card2Filled, width: cardW, height: cardH, color: color),
      ],
    );
  }
}

/// A single score card showing 6 diamond slots in a 3×2 grid.
/// [filled]=0 → card back.
/// [filled]=1–6 → white face with that many diamonds lit.
class _ScoreCard extends StatelessWidget {
  final int filled;
  final double width;
  final double height;
  final Color color;

  const _ScoreCard({
    required this.filled,
    required this.width,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (filled == 0) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.indigo.shade900,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white24, width: 0.5),
        ),
        child: Center(
          child: Container(
            width: width * 0.55,
            height: height * 0.55,
            decoration: BoxDecoration(
              color: Colors.indigo.shade700,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      );
    }

    final diamondSize = (height * 0.18).clamp(8.0, 16.0);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade400, width: 0.5),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: width * 0.08,
        vertical: height * 0.06,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (int row = 0; row < 3; row++)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (int col = 0; col < 2; col++)
                  _diamond(row * 2 + col < filled, diamondSize),
              ],
            ),
        ],
      ),
    );
  }

  Widget _diamond(bool lit, double size) {
    return Text(
      lit ? '\u25C6' : '\u25C7',
      style: TextStyle(
        color: lit ? color : Colors.grey.shade300,
        fontSize: size,
        height: 1,
      ),
    );
  }
}
