import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/models/round_state.dart';
import '../../../state/providers/game_state_provider.dart';
import '../../../state/providers/local_seat_provider.dart';
import '../../../utils/constants.dart';

/// Compact floating bidding bubble.
/// Shows one bid button (next increment) + X to pass/dismiss.
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
    final isHighestBidder = highestBidder != null && highestBidder == localSeat;
    final nextBid = currentBid + BID_INCREMENT;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xF0102040), Color(0xF00A1830)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0x5064B5F6),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x3064B5F6), blurRadius: 18, spreadRadius: 1),
          BoxShadow(color: Color(0x90000000), blurRadius: 10),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Current bid info
          if (currentBid > 0)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(
                '${highestBidder?.name}: $currentBid',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          // Single bid button (next increment only)
          if (nextBid <= 50 && !isHighestBidder)
            GestureDetector(
              onTap: () => ref.read(matchStateProvider.notifier).makeBid(nextBid),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.blue.shade400,
                      Colors.blue.shade700,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white24, width: 0.8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  'Bid $nextBid',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),

          if (isHighestBidder)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Your bid: $currentBid',
                style: TextStyle(
                  color: Colors.blue.shade200,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          const SizedBox(width: 8),

          // X button to pass
          GestureDetector(
            onTap: isHighestBidder
                ? null
                : () => ref.read(matchStateProvider.notifier).passBid(),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isHighestBidder
                    ? Colors.white10
                    : const Color(0x40FF5252),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isHighestBidder ? Colors.white10 : Colors.red.shade400.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.close,
                size: 16,
                color: isHighestBidder ? Colors.white24 : Colors.red.shade300,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
