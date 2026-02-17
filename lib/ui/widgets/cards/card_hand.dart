import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../domain/models/card.dart' as game_card;
import '../../../state/providers/game_state_provider.dart';
import 'playing_card_widget.dart';
import 'card_animations.dart';

/// Displays a hand of cards in a horizontal row.
///
/// [cardHeight] controls the rendered card height (width derived from aspect
/// ratio 2:3). When null, falls back to [CardSize.large] scaled from screen.
class CardHand extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    if (cards.isEmpty) return const SizedBox.shrink();

    // Resolve card dimensions
    final ch = cardHeight ?? (MediaQuery.sizeOf(context).height * 0.27).clamp(72.0, 112.0);
    final cw = ch * 0.67;

    final legalCards = ref.watch(legalCardsProvider);
    final isHumanTurn = ref.watch(isHumanTurnProvider);

    return SizedBox(
      height: ch, // exact card height; box shadow extends outside but doesn't cause overflow
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: cards.asMap().entries.map((entry) {
          final index = entry.key;
          final game_card.Card card = entry.value;
          final isLegal = legalCards.contains(card);
          final canPlay = isVisible && isHumanTurn && isLegal;

          return Padding(
            padding: EdgeInsets.only(left: index > 0 ? 4 : 0),
            child: isVisible && isHumanTurn
                ? PulseCardWidget(
                    card: card,
                    isLegal: isLegal,
                    width: cw,
                    height: ch,
                    onTap: canPlay
                        ? () => ref.read(matchStateProvider.notifier).playCard(card)
                        : null,
                  )
                : PlayingCardWidget(
                    card: isVisible ? card : null,
                    width: cw,
                    height: ch,
                    isSelected: false,
                  ),
          ).animate().fadeIn(
                duration: const Duration(milliseconds: 300),
                delay: Duration(milliseconds: 50 * index),
              );
        }).toList(),
      ),
    );
  }
}
