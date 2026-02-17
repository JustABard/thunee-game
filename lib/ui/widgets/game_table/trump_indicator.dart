import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../domain/models/card.dart' as game_card;
import '../../../domain/models/suit.dart';

/// Displays the current trump suit.
/// When [trumpCard] is provided (i.e. trump was just chosen), shows the card
/// name briefly before collapsing to just the suit icon.
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
  bool _showCard = false;
  Suit? _lastSuit;

  @override
  void didUpdateWidget(TrumpIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When trump suit first appears (was null, now set), show the card reveal
    if (oldWidget.trumpSuit == null && widget.trumpSuit != null) {
      _showCard = true;
      _lastSuit = widget.trumpSuit;
      // After 2.5 seconds, collapse to just the suit
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) {
          setState(() => _showCard = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.trumpSuit == null) {
      return const SizedBox.shrink();
    }

    final teamColor = widget.trumpMakingTeam == 0 ? Colors.blue : Colors.red;
    final suitColor = widget.trumpSuit!.isRed ? Colors.red.shade900 : Colors.black;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      padding: EdgeInsets.symmetric(
        horizontal: _showCard ? 12 : 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: teamColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: teamColor.withValues(alpha: 0.5),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Trump:',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 6),
          // Show the full card name during reveal, then just the suit
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _showCard && widget.trumpCard != null
                ? Text(
                    widget.trumpCard!.shortName,
                    key: const ValueKey('card'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: suitColor,
                      shadows: const [
                        Shadow(color: Colors.white, blurRadius: 2),
                      ],
                    ),
                  )
                : Text(
                    widget.trumpSuit!.symbol,
                    key: const ValueKey('suit'),
                    style: TextStyle(
                      fontSize: 16,
                      color: suitColor,
                      shadows: const [
                        Shadow(color: Colors.white, blurRadius: 2),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: const Duration(milliseconds: 300))
        .scale(
          begin: const Offset(0.5, 0.5),
          end: const Offset(1.0, 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.elasticOut,
        );
  }
}
