import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../domain/models/card.dart' as game_card;
import '../../../state/providers/game_state_provider.dart';
import 'playing_card_widget.dart';
import 'card_animations.dart';

/// Displays a hand of cards in a fan layout
class CardHand extends ConsumerWidget {
  final List<game_card.Card> cards;
  final bool isVisible;

  const CardHand({
    super.key,
    required this.cards,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cards.isEmpty) {
      return const SizedBox(height: 120);
    }

    final legalCards = ref.watch(legalCardsProvider);
    final isHumanTurn = ref.watch(isHumanTurnProvider);

    return SizedBox(
      height: 140,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
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
                    size: CardSize.large,
                    onTap: canPlay
                        ? () => ref.read(matchStateProvider.notifier).playCard(card)
                        : null,
                  )
                : PlayingCardWidget(
                    card: isVisible ? card : null,
                    size: CardSize.large,
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
