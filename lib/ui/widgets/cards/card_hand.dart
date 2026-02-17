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
    final isChoosingTrump = ref.watch(isChoosingTrumpProvider);

    return SizedBox(
      height: ch,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: cards.asMap().entries.map((entry) {
          final index = entry.key;
          final game_card.Card card = entry.value;

          Widget cardWidget;

          if (isChoosingTrump) {
            // All cards are selectable as trump — green shimmer
            cardWidget = PulseCardWidget(
              card: card,
              isLegal: true,
              width: cw,
              height: ch,
              shimmerColor: Colors.green.withOpacity(0.45),
              onTap: () => ref.read(matchStateProvider.notifier).selectTrump(card),
            );
          } else if (isVisible && isHumanTurn) {
            // Normal play — legal cards highlighted yellow, illegal dimmed
            final isLegal = legalCards.contains(card);
            cardWidget = PulseCardWidget(
              card: card,
              isLegal: isLegal,
              width: cw,
              height: ch,
              shimmerColor: Colors.yellow.withOpacity(0.3),
              onTap: isLegal
                  ? () => ref.read(matchStateProvider.notifier).playCard(card)
                  : null,
            );
          } else {
            cardWidget = PlayingCardWidget(
              card: isVisible ? card : null,
              width: cw,
              height: ch,
              isSelected: false,
            );
          }

          return Padding(
            padding: EdgeInsets.only(left: index > 0 ? 4 : 0),
            child: cardWidget,
          ).animate().fadeIn(
                duration: const Duration(milliseconds: 300),
                delay: Duration(milliseconds: 50 * index),
              );
        }).toList(),
      ),
    );
  }
}
