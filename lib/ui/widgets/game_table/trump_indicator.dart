import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../domain/models/suit.dart';

/// Displays the current trump suit with animation
class TrumpIndicator extends StatelessWidget {
  final Suit? trumpSuit;
  final int trumpMakingTeam;

  const TrumpIndicator({
    super.key,
    required this.trumpSuit,
    required this.trumpMakingTeam,
  });

  @override
  Widget build(BuildContext context) {
    if (trumpSuit == null) {
      return const SizedBox.shrink();
    }

    final teamColor = trumpMakingTeam == 0 ? Colors.blue : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: teamColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: teamColor.withOpacity(0.5),
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
          Text(
            trumpSuit!.symbol,
            style: TextStyle(
              fontSize: 16,
              color: trumpSuit!.isRed ? Colors.red.shade900 : Colors.black,
              shadows: [
                const Shadow(
                  color: Colors.white,
                  blurRadius: 2,
                ),
              ],
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
        )
        .shimmer(
          duration: const Duration(seconds: 2),
          color: Colors.white38,
        );
  }
}
