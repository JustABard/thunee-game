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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Colors.black26,
        child: const Center(
          child: Text(
            'Waiting for opponent to bid...',
            style: TextStyle(color: Colors.white, fontSize: 13),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (currentBid > 0) ...[
            Text(
              'Bid: $currentBid',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(width: 16),
          ],
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pass button
              ElevatedButton.icon(
                onPressed: () => ref.read(matchStateProvider.notifier).passBid(),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Pass'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              )
                  .animate()
                  .fadeIn(delay: const Duration(milliseconds: 100))
                  .scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),

              const SizedBox(width: 12),

              // Bid buttons
              ...List.generate(3, (index) {
                final bidAmount = nextBid + (index * BID_INCREMENT);
                if (bidAmount > 50) return const SizedBox.shrink();

                return Padding(
                  padding: EdgeInsets.only(left: index > 0 ? 8 : 0),
                  child: ElevatedButton(
                    onPressed: () =>
                        ref.read(matchStateProvider.notifier).makeBid(bidAmount),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    child: Text('$bidAmount'),
                  )
                      .animate()
                      .fadeIn(delay: Duration(milliseconds: 200 + (index * 80)))
                      .scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}
