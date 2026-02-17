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
    final currentBid = roundState.highestBid?.amount ?? 0;
    final highestBidder = roundState.highestBid?.caller;

    // Calculate next valid bid
    final nextBid = currentBid + BID_INCREMENT;

    // Default trump-maker label (dealer.next gets trump if everyone passes)
    final defaultTrumpSeat = roundState.dealer.next;
    final defaultTrumpName = roundState.playerAt(defaultTrumpSeat).name;

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
          // Default trump-maker info
          Text(
            'Default trump: $defaultTrumpName',
            style: TextStyle(color: Colors.white38, fontSize: 10),
          ),
          const SizedBox(width: 12),
          if (currentBid > 0) ...[
            Text(
              'Bid: $currentBid (${highestBidder?.name ?? ""})',
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
