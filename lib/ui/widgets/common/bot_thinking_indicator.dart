import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Shows a subtle indicator when bot is "thinking"
class BotThinkingIndicator extends StatelessWidget {
  final bool isVisible;
  final String? message;

  const BotThinkingIndicator({
    super.key,
    required this.isVisible,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Positioned(
      top: 80,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              message ?? 'Bot thinking...',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ),
      )
          .animate()
          .fadeIn(duration: const Duration(milliseconds: 200))
          .scale(
            begin: const Offset(0.8, 0.8),
            curve: Curves.easeOut,
          ),
    );
  }
}
