import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../domain/models/card.dart' as game_card;
import '../../../domain/models/suit.dart';
import '../cards/playing_card_widget.dart';

/// Displays the current trump suit with a card flip reveal animation.
///
/// When trump is first set, the trump card is shown face-down then flips to
/// reveal the front. After [_revealDuration] the card slides away, leaving
/// just the compact suit pill.
class TrumpIndicator extends StatefulWidget {
  final Suit? trumpSuit;
  final game_card.Card? trumpCard;
  final int trumpMakingTeam;

  const TrumpIndicator({
    super.key,
    required this.trumpSuit,
    required this.trumpCard,
    required this.trumpMakingTeam,
  });

  @override
  State<TrumpIndicator> createState() => _TrumpIndicatorState();
}

class _TrumpIndicatorState extends State<TrumpIndicator> {
  static const _flipDelay    = Duration(milliseconds: 400);
  static const _revealDur   = Duration(milliseconds: 3200);

  bool _showCard   = false; // whether the card widget is in the tree
  bool _cardFront  = false; // whether the card should show its front

  @override
  void initState() {
    super.initState();
    // If widget enters tree with trump already set, start the reveal immediately
    if (widget.trumpSuit != null && widget.trumpCard != null) {
      _beginReveal();
    }
  }

  @override
  void didUpdateWidget(TrumpIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.trumpSuit == null && widget.trumpSuit != null) {
      _beginReveal();
    }
  }

  void _beginReveal() {
    setState(() {
      _showCard  = true;
      _cardFront = false;
    });

    // Flip card to front after a short delay.
    Future.delayed(_flipDelay, () {
      if (mounted) setState(() => _cardFront = true);
    });

    // Hide card after reveal; suit pill persists forever.
    Future.delayed(_revealDur, () {
      if (mounted) setState(() => _showCard = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.trumpSuit == null) return const SizedBox.shrink();

    final teamColor = widget.trumpMakingTeam == 0 ? Colors.blue : Colors.red;
    final suitColor = widget.trumpSuit!.isRed
        ? Colors.red.shade800
        : Colors.grey.shade900;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Flipping trump card ─────────────────────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          child: _showCard && widget.trumpCard != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FlipCard(
                    card: widget.trumpCard!,
                    showFront: _cardFront,
                  ),
                )
              : const SizedBox.shrink(),
        ),

        // ── Trump suit pill ─────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: teamColor.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: teamColor.withValues(alpha: 0.55),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'TRUMP',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                widget.trumpSuit!.symbol,
                style: TextStyle(
                  fontSize: 18,
                  color: suitColor,
                  shadows: const [Shadow(color: Colors.white70, blurRadius: 3)],
                ),
              ),
            ],
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(duration: const Duration(milliseconds: 300))
        .scale(
          begin: const Offset(0.4, 0.4),
          end: const Offset(1.0, 1.0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.elasticOut,
        );
  }
}

// ── Internal flip card widget ───────────────────────────────────────────────

/// A playing card that animates from face-down to face-up.
///
/// Uses a two-phase approach:
///   Phase 1 (0 → 0.5): back face rotates from 0° → 90°  (face-down to edge)
///   Phase 2 (0.5 → 1): front face rotates from 90° → 0° (edge to face-up)
/// No mirroring artefacts at rest positions.
class _FlipCard extends StatefulWidget {
  final game_card.Card card;
  final bool showFront;

  const _FlipCard({required this.card, required this.showFront});

  @override
  State<_FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<_FlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    if (widget.showFront) _ctrl.forward();
  }

  @override
  void didUpdateWidget(_FlipCard old) {
    super.didUpdateWidget(old);
    if (widget.showFront != old.showFront) {
      widget.showFront ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fixed card size for the reveal widget
    const cardH = 54.0;
    const cardW = cardH * 0.67;

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final v = _anim.value; // 0.0 → 1.0
        final showFront = v >= 0.5;

        // Phase 1: back rotates 0° → 90°
        // Phase 2: front rotates 90° → 0°
        final angle = showFront
            ? (1.0 - v) * 2 * math.pi / 2   // π/2 → 0
            : v * 2 * math.pi / 2;           // 0 → π/2

        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // perspective
            ..rotateY(angle),
          alignment: Alignment.center,
          child: showFront
              ? PlayingCardWidget(
                  card: widget.card,
                  width: cardW,
                  height: cardH,
                )
              : PlayingCardWidget(
                  card: null, // back face
                  width: cardW,
                  height: cardH,
                ),
        );
      },
    );
  }
}
