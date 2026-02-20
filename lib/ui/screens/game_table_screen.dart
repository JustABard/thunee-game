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
                  // ── Main layout: table fills entire screen ────────────
                  TableLayout(roundState: roundState),

                  // ── Floating call/bid panels above south player's cards ─
                  // Position panels just above the south zone (26% from bottom)
                  if (roundState.phase == RoundPhase.bidding)
                    const Positioned.fill(
                      child: _FloatingPanelPositioner(
                        child: _BiddingPanelWrapper(),
                      ),
                    ),
                  if (roundState.phase == RoundPhase.choosingTrump)
                    Positioned.fill(
                      child: _FloatingPanelPositioner(
                        child: _TrumpChoiceBanner(isBotChoosing: isBotTurn),
                      ),
                    ),
                  if (canCallThunee)
                    const Positioned.fill(
                      child: _FloatingPanelPositioner(
                        child: _ThuneeCallPanel(),
                      ),
                    ),
                  if (jodiWindowOpen && jodiCombos.isNotEmpty)
                    Positioned.fill(
                      child: _FloatingPanelPositioner(
                        child: _JodiCallPanel(combos: jodiCombos),
                      ),
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
                        if (matchState.isComplete) {
                          // Match is over — go back to home
                          ref.read(matchStateProvider.notifier).dismissRoundResult();
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        } else {
                          ref.read(matchStateProvider.notifier).dismissRoundResult();
                        }
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

/// Positions a floating panel just above the south zone (26% from bottom).
class _FloatingPanelPositioner extends StatelessWidget {
  final Widget child;
  const _FloatingPanelPositioner({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final southH = constraints.maxHeight * 0.26;
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: southH + 4, left: 20, right: 20),
            child: child,
          ),
        );
      },
    );
  }
}

/// Wrapper that passes roundState to BiddingPanel from provider.
class _BiddingPanelWrapper extends ConsumerWidget {
  const _BiddingPanelWrapper();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roundState = ref.watch(roundStateProvider);
    if (roundState == null) return const SizedBox.shrink();
    return BiddingPanel(roundState: roundState);
  }
}

/// Panel for calling Thunee or Royals before the first trick.
/// 15-second countdown with progress bar. Skip ends immediately.
class _ThuneeCallPanel extends ConsumerStatefulWidget {
  const _ThuneeCallPanel();

  @override
  ConsumerState<_ThuneeCallPanel> createState() => _ThuneeCallPanelState();
}

class _ThuneeCallPanelState extends ConsumerState<_ThuneeCallPanel>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(seconds: 15);
  late final AnimationController _timerController;

  @override
  void initState() {
    super.initState();
    _timerController = AnimationController(
      vsync: this,
      duration: _duration,
    )..forward();

    _timerController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _dismiss();
      }
    });
  }

  @override
  void dispose() {
    _timerController.dispose();
    super.dispose();
  }

  void _dismiss() {
    ref.read(thuneePromptDismissedProvider.notifier).state = true;
    ref.read(matchStateProvider.notifier).dismissCallWindow();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade900, Colors.indigo.shade900],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.shade600.withValues(alpha: 0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withValues(alpha: 0.3),
            blurRadius: 16,
            spreadRadius: 2,
          ),
          const BoxShadow(color: Colors.black54, blurRadius: 8),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Compact timer bar
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: AnimatedBuilder(
              animation: _timerController,
              builder: (context, _) {
                return LinearProgressIndicator(
                  value: 1.0 - _timerController.value,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color.lerp(Colors.purple.shade300, Colors.red.shade400,
                        _timerController.value)!,
                  ),
                  minHeight: 2,
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Special call?',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 14),
              _callButton(
                label: 'THUNEE',
                icon: Icons.flash_on,
                color: Colors.purple.shade400,
                onTap: () {
                  ref.read(matchStateProvider.notifier).callThunee();
                  _dismiss();
                },
              ),
              const SizedBox(width: 8),
              _callButton(
                label: 'ROYALS',
                icon: Icons.workspace_premium,
                color: Colors.indigo.shade400,
                onTap: () {
                  ref.read(matchStateProvider.notifier).callRoyals();
                  _dismiss();
                },
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _dismiss,
                style: TextButton.styleFrom(foregroundColor: Colors.white38),
                child: const Text('Skip', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _callButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 4,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade800, Colors.teal.shade800],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade500.withValues(alpha: 0.4), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.green.withValues(alpha: 0.25), blurRadius: 12, spreadRadius: 1),
          const BoxShadow(color: Colors.black54, blurRadius: 8),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isBotChoosing ? Icons.hourglass_empty : Icons.touch_app,
            color: Colors.white70,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            isBotChoosing
                ? 'Opponent is choosing trump…'
                : 'Tap any card to set trump',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows each team's trick points + Jodi calls during the current round.
///
/// Jodi rows are always rendered (static section) — empty when none called.
/// Layout:
///   [Active Thunee/Royals banner]
///   ● Team 1   X pts  (Y tricks)
///     Jodi: badge badge …  or  "—"
///   ─────────────────────────────
///   ● Team 2   X pts  (Y tricks)
///     Jodi: badge badge …  or  "—"
class _TrickPointsTracker extends StatelessWidget {
  final RoundState roundState;

  const _TrickPointsTracker({required this.roundState});

  @override
  Widget build(BuildContext context) {
    final t0 = roundState.teams[0]; // South + North
    final t1 = roundState.teams[1]; // West + East

    final activeCall = roundState.activeThuneeCall;

    final jodiCalls = roundState.specialCalls
        .where((c) => c.category == CallCategory.jodi)
        .cast<JodiCall>()
        .toList();
    final t0Jodis = jodiCalls.where((j) => j.caller.teamNumber == 0).toList();
    final t1Jodis = jodiCalls.where((j) => j.caller.teamNumber == 1).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12, width: 0.8),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Active Thunee/Royals banner
          if (activeCall != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              margin: const EdgeInsets.only(bottom: 5),
              decoration: BoxDecoration(
                color: Colors.amber.shade800,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                '${activeCall.category.name.toUpperCase()} \u2605 ${activeCall.caller.name}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],

          // ── Team 1 ────────────────────────────────────────────────
          _teamHeader('T1', t0.pointsCollected, t0.tricksWon, Colors.blue.shade300),
          _jodiRow(t0Jodis),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Divider(height: 1, thickness: 0.6, color: Colors.white12),
          ),

          // ── Team 2 ────────────────────────────────────────────────
          _teamHeader('T2', t1.pointsCollected, t1.tricksWon, Colors.red.shade300),
          _jodiRow(t1Jodis),
        ],
      ),
    );
  }

  Widget _teamHeader(String label, int points, int tricks, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 7),
        Text(
          '$points pts',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '($tricks \u2605)',
          style: const TextStyle(color: Colors.white54, fontSize: 8),
        ),
      ],
    );
  }

  /// Always renders a jodi section — shows badges when present, dash when empty.
  Widget _jodiRow(List<JodiCall> jodis) {
    return Padding(
      padding: const EdgeInsets.only(left: 11, top: 2, bottom: 1),
      child: jodis.isEmpty
          ? const Text(
              'Jodi  —',
              style: TextStyle(color: Colors.white24, fontSize: 8),
            )
          : Wrap(
              spacing: 4,
              runSpacing: 2,
              children: [
                const Text(
                  'Jodi',
                  style: TextStyle(color: Colors.white38, fontSize: 8),
                ),
                ...jodis.map(
                  (j) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: j.isTrump
                          ? Colors.amber.shade800.withValues(alpha: 0.85)
                          : Colors.teal.shade700.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${j.cards.map((c) => c.shortName).join("+")}${j.isTrump ? " \u2666" : ""}  +${j.points}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade900, Colors.green.shade900],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.shade500.withValues(alpha: 0.4), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.teal.withValues(alpha: 0.25), blurRadius: 12, spreadRadius: 1),
          const BoxShadow(color: Colors.black54, blurRadius: 8),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Jodi!',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 14),
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
                  backgroundColor: isTrump ? Colors.amber.shade600 : Colors.teal.shade500,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 4,
                ),
                child: Text(
                  '$label${isTrump ? " \u2666" : ""}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            );
          }),
          TextButton(
            onPressed: () => ref.read(matchStateProvider.notifier).dismissJodiWindow(),
            style: TextButton.styleFrom(foregroundColor: Colors.white38),
            child: const Text('Skip', style: TextStyle(fontSize: 11)),
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
        color: Colors.black.withValues(alpha: 0.88),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
            margin: const EdgeInsets.symmetric(horizontal: 48),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A1A1A), Color(0xFF111111)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.amber.shade600, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.2),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
                const BoxShadow(color: Colors.black54, blurRadius: 16),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.emoji_events, color: Colors.amber.shade400, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      matchState.isComplete ? 'MATCH OVER' : 'ROUND COMPLETE',
                      style: TextStyle(
                        color: Colors.amber.shade300,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.emoji_events, color: Colors.amber.shade400, size: 20),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  result,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ScoreColumn(label: t0.name, balls: t0.balls, color: Colors.blue),
                    Container(width: 1, height: 60, color: Colors.white12),
                    _ScoreColumn(label: t1.name, balls: t1.balls, color: Colors.red),
                  ],
                ),
                const SizedBox(height: 18),
                if (matchState.isComplete) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade800,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${matchState.winner?.name ?? "A team"} wins! \u2605',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.home, color: Colors.white38, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Tap to return home',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                      ),
                    ],
                  ),
                ] else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.touch_app, color: Colors.white24, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Tap to continue',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                      ),
                    ],
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12, width: 0.8),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DiamondScoreRow(label: 'T1', balls: t0.balls, color: Colors.blue.shade300),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Divider(height: 1, thickness: 0.5, color: Colors.white12),
          ),
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
