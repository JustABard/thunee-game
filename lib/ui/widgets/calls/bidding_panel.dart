import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../domain/models/round_state.dart';
import '../../../state/providers/game_state_provider.dart';
import '../../../state/providers/local_seat_provider.dart';
import '../../../utils/constants.dart';

/// Panel for bidding during bidding phase.
/// 10-second countdown timer that resets after each bid. Skip = pass immediately.
class BiddingPanel extends ConsumerStatefulWidget {
  final RoundState roundState;

  const BiddingPanel({super.key, required this.roundState});

  @override
  ConsumerState<BiddingPanel> createState() => _BiddingPanelState();
}

class _BiddingPanelState extends ConsumerState<BiddingPanel>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(seconds: 10);
  late AnimationController _timerController;
  int? _lastBidAmount;

  @override
  void initState() {
    super.initState();
    _timerController = AnimationController(
      vsync: this,
      duration: _duration,
    )..forward();

    _timerController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        // Auto-pass when timer runs out (only if not the highest bidder)
        final rs = widget.roundState;
        final localSeat = ref.read(localSeatProvider);
        final isHighest = rs.highestBid != null && rs.highestBid!.caller == localSeat;
        if (!isHighest) {
          ref.read(matchStateProvider.notifier).passBid();
        }
      }
    });

    _lastBidAmount = widget.roundState.highestBid?.amount;
  }

  @override
  void didUpdateWidget(BiddingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reset timer when bid changes
    final newBidAmount = widget.roundState.highestBid?.amount;
    if (newBidAmount != _lastBidAmount) {
      _lastBidAmount = newBidAmount;
      _timerController.reset();
      _timerController.forward();
    }
  }

  @override
  void dispose() {
    _timerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentBid = widget.roundState.highestBid?.amount ?? 0;
    final highestBidder = widget.roundState.highestBid?.caller;
    final localSeat = ref.watch(localSeatProvider);
    // Human is the highest bidder — can't pass on own bid
    final isHighestBidder = highestBidder != null && highestBidder == localSeat;

    final nextBid = currentBid + BID_INCREMENT;

    final defaultTrumpSeat = widget.roundState.dealer.next;
    final defaultTrumpName =
        widget.roundState.playerAt(defaultTrumpSeat).name;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xEE1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.4), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.amber.withValues(alpha: 0.15), blurRadius: 12, spreadRadius: 1),
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
                    Color.lerp(Colors.green.shade400, Colors.red.shade400,
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
              // Default trump-maker info
              Text(
                'Trump: $defaultTrumpName',
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
              const SizedBox(width: 10),
              if (currentBid > 0) ...[
                Text(
                  'Bid: $currentBid (${highestBidder?.name ?? ""})',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 12),
              ],
              // Pass button (disabled when human holds highest bid)
              ElevatedButton.icon(
                onPressed: isHighestBidder
                    ? null
                    : () => ref.read(matchStateProvider.notifier).passBid(),
                icon: const Icon(Icons.close, size: 14),
                label: Text(isHighestBidder ? 'Your bid' : 'Pass',
                    style: const TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              )
                  .animate()
                  .fadeIn(delay: const Duration(milliseconds: 100))
                  .scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
              const SizedBox(width: 8),
              // Bid buttons
              ...List.generate(3, (index) {
                final bidAmount = nextBid + (index * BID_INCREMENT);
                if (bidAmount > 50) return const SizedBox.shrink();

                return Padding(
                  padding: EdgeInsets.only(left: index > 0 ? 6 : 0),
                  child: ElevatedButton(
                    onPressed: () => ref
                        .read(matchStateProvider.notifier)
                        .makeBid(bidAmount),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('$bidAmount', style: const TextStyle(fontSize: 12)),
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
