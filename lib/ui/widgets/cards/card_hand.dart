import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../domain/models/card.dart' as game_card;
import '../../../domain/utils/card_sorter.dart';
import '../../../state/providers/game_state_provider.dart';
import 'playing_card_widget.dart';
import 'card_animations.dart';

/// Displays a hand of cards in a horizontal row.
///
/// Cards are always displayed in sorted order (grouped by suit).
/// - On initial deal: cards animate in from below with staggered timing.
/// - When a card is played: remaining cards stay sorted, no entrance anim.
/// - When cards increase (4→6): re-sorted instantly.
class CardHand extends ConsumerStatefulWidget {
  final List<game_card.Card> cards;
  final bool isVisible;
  final double? cardHeight;

  const CardHand({
    super.key,
    required this.cards,
    this.isVisible = true,
    this.cardHeight,
  });

  @override
  ConsumerState<CardHand> createState() => _CardHandState();
}

class _CardHandState extends ConsumerState<CardHand>
    with TickerProviderStateMixin {
  bool _isNewDeal = true;

  /// Always-sorted version of the current cards.
  late List<game_card.Card> _sortedCards;

  @override
  void initState() {
    super.initState();
    _isNewDeal = true;
    _sortedCards = sortHandBySuit(widget.cards);
    if (widget.cards.isNotEmpty) {
      _scheduleEndDeal();
    }
  }

  @override
  void didUpdateWidget(CardHand oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldLen = oldWidget.cards.length;
    final newLen = widget.cards.length;

    if (newLen > oldLen && oldLen <= 1) {
      // Fresh deal (0/1 → many)
      _isNewDeal = true;
      _sortedCards = sortHandBySuit(widget.cards);
      _scheduleEndDeal();
    } else if (newLen > oldLen && oldLen > 1) {
      // Mid-round card increase (4→6 after trump selection)
      _isNewDeal = false;
      _sortedCards = sortHandBySuit(widget.cards);
    } else if (newLen < oldLen) {
      // Card played — re-sort
      _isNewDeal = false;
      _sortedCards = sortHandBySuit(widget.cards);
    } else if (newLen == oldLen && newLen > 0) {
      if (!_sameCards(oldWidget.cards, widget.cards)) {
        // New round with same card count
        _isNewDeal = true;
        _sortedCards = sortHandBySuit(widget.cards);
        _scheduleEndDeal();
      }
    }
  }

  void _scheduleEndDeal() {
    final delay = 100 * widget.cards.length + 600;
    Future.delayed(Duration(milliseconds: delay), () {
      if (!mounted) return;
      setState(() => _isNewDeal = false);
    });
  }

  bool _sameCards(List<game_card.Card> a, List<game_card.Card> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) return const SizedBox.shrink();

    final ch = widget.cardHeight ??
        (MediaQuery.sizeOf(context).height * 0.27).clamp(72.0, 112.0);
    final cw = ch * 0.67;

    final legalCards = ref.watch(legalCardsProvider);
    final isHumanTurn = ref.watch(isHumanTurnProvider);
    final isChoosingTrump = ref.watch(isChoosingTrumpProvider);

    final displayCards = _sortedCards;

    return SizedBox(
      height: ch,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: displayCards.asMap().entries.map((entry) {
          final index = entry.key;
          final game_card.Card card = entry.value;

          Widget cardWidget;

          if (isChoosingTrump) {
            cardWidget = PulseCardWidget(
              card: card,
              isLegal: true,
              width: cw,
              height: ch,
              shimmerColor: Colors.green.withValues(alpha: 0.45),
              onTap: () =>
                  ref.read(matchStateProvider.notifier).selectTrump(card),
            );
          } else if (widget.isVisible && isHumanTurn) {
            final isLegal = legalCards.contains(card);
            cardWidget = PulseCardWidget(
              card: card,
              isLegal: isLegal,
              width: cw,
              height: ch,
              shimmerColor: Colors.yellow.withValues(alpha: 0.30),
              onTap: isLegal
                  ? () =>
                      ref.read(matchStateProvider.notifier).playCard(card)
                  : null,
            );
          } else {
            cardWidget = PlayingCardWidget(
              card: widget.isVisible ? card : null,
              width: cw,
              height: ch,
              isSelected: false,
            );
          }

          // Only apply entrance animation on new deal
          if (_isNewDeal) {
            final fanAngle = _fanAngle(index, displayCards.length);
            return Padding(
              padding: EdgeInsets.only(left: index > 0 ? 4 : 0),
              child: cardWidget,
            )
                .animate(
                  key: ValueKey(
                      'deal-${card.rank.name}-${card.suit.name}-${widget.cards.length}'),
                )
                .fadeIn(
                  duration: const Duration(milliseconds: 300),
                  delay: Duration(milliseconds: 100 * index),
                )
                .slideY(
                  begin: 1.6,
                  end: 0,
                  duration: const Duration(milliseconds: 500),
                  delay: Duration(milliseconds: 100 * index),
                  curve: Curves.easeOutCubic,
                )
                .scale(
                  begin: const Offset(0.6, 0.6),
                  end: const Offset(1.0, 1.0),
                  duration: const Duration(milliseconds: 450),
                  delay: Duration(milliseconds: 100 * index),
                  curve: Curves.easeOutCubic,
                )
                .rotate(
                  begin: fanAngle * 0.15,
                  end: 0,
                  duration: const Duration(milliseconds: 500),
                  delay: Duration(milliseconds: 100 * index),
                  curve: Curves.easeOutCubic,
                );
          }

          // No entrance animation — just show card
          return Padding(
            padding: EdgeInsets.only(left: index > 0 ? 4 : 0),
            child: cardWidget,
          );
        }).toList(),
      ),
    );
  }

  double _fanAngle(int index, int total) {
    if (total <= 1) return 0;
    final mid = (total - 1) / 2.0;
    return (index - mid) / total;
  }
}
