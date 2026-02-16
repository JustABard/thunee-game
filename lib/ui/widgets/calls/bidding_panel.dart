import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../domain/models/round_state.dart';
import '../../../state/providers/game_state_provider.dart';
import '../../../utils/constants.dart';

/// Panel for bidding during bidding phase
class BiddingPanel extends ConsumerWidget {
  final RoundState roundState;

  const BiddingPanel({super.key, required this.roundState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isHumanTurn = ref.watch(isHumanTurnProvider);
    final currentBid = roundState.highestBid?.amount ?? 0;

    if (!isHumanTurn) {
      return Container(
        padding: const EdgeInsets.all(16),
        color: Colors.black26,
        child: const Center(
          child: Text(
            'Waiting for opponent to bid...',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      )
          .animate()
          .fadeIn(duration: const Duration(milliseconds: 300))
          .shimmer(
            duration: const Duration(seconds: 2),
            color: Colors.white24,
          );
    }

    // Calculate next valid bid
    final nextBid = currentBid + BID_INCREMENT;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (currentBid > 0)
            Text(
              'Current bid: $currentBid',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Pass button
              ElevatedButton.icon(
                onPressed: () => ref.read(matchStateProvider.notifier).passBid(),
                icon: const Icon(Icons.close),
                label: const Text('Pass'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              )
                  .animate()
                  .fadeIn(delay: const Duration(milliseconds: 100))
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    curve: Curves.easeOutBack,
                  ),

              // Bid buttons
              ...List.generate(3, (index) {
                final bidAmount = nextBid + (index * BID_INCREMENT);
                if (bidAmount > 50) return const SizedBox.shrink();

                return ElevatedButton(
                  onPressed: () => ref.read(matchStateProvider.notifier).makeBid(bidAmount),
                  child: Text('$bidAmount'),
                )
                    .animate()
                    .fadeIn(delay: Duration(milliseconds: 200 + (index * 100)))
                    .scale(
                      begin: const Offset(0.8, 0.8),
                      curve: Curves.easeOutBack,
                    );
              }),
            ],
          ),
        ],
      ),
    );
  }
}
