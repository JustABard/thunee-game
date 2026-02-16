import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Handover screen for pass-and-play mode
/// Shows between turns to prevent players from seeing each other's cards
class HandoverScreen extends StatelessWidget {
  final String nextPlayerName;
  final VoidCallback onReady;
  final bool isVisible;

  const HandoverScreen({
    super.key,
    required this.nextPlayerName,
    required this.onReady,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Material(
      color: Colors.black87,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              const Icon(
                Icons.swap_horiz_rounded,
                size: 80,
                color: Colors.white,
              )
                  .animate(onPlay: (controller) => controller.repeat())
                  .shake(duration: const Duration(seconds: 2)),

              const SizedBox(height: 32),

              // Title
              const Text(
                'Pass Device',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ).animate().fadeIn().slideY(begin: -0.5, end: 0),

              const SizedBox(height: 16),

              // Next player name
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.shade700.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Text(
                  nextPlayerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: const Duration(milliseconds: 300))
                  .scale(
                    delay: const Duration(milliseconds: 300),
                    curve: Curves.elasticOut,
                  ),

              const SizedBox(height: 48),

              // Instructions
              const Text(
                'Make sure only this player can see the screen',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: const Duration(milliseconds: 600)),

              const SizedBox(height: 32),

              // Ready button
              ElevatedButton.icon(
                onPressed: onReady,
                icon: const Icon(Icons.visibility, size: 28),
                label: const Text(
                  "I'm Ready - Show Cards",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: const Duration(milliseconds: 900))
                  .scale(
                    delay: const Duration(milliseconds: 900),
                    curve: Curves.easeOut,
                  )
                  .then()
                  .shimmer(
                    duration: const Duration(seconds: 2),
                    color: Colors.white24,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Overlay widget that can be shown on top of game table
class HandoverOverlay extends StatelessWidget {
  final String nextPlayerName;
  final VoidCallback onReady;

  const HandoverOverlay({
    super.key,
    required this.nextPlayerName,
    required this.onReady,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Blur/darken the background
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.95),
          ).animate().fadeIn(duration: const Duration(milliseconds: 300)),
        ),

        // Handover screen
        HandoverScreen(
          nextPlayerName: nextPlayerName,
          onReady: onReady,
        ),
      ],
    );
  }
}
