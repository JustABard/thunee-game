import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/models/card.dart' as game_card;
import '../../../domain/models/player.dart';
import '../../../domain/models/round_state.dart';
import '../../../state/providers/ui_state_provider.dart';
import '../cards/card_hand.dart';
import '../cards/playing_card_widget.dart';
import 'trump_indicator.dart';

/// Main game table layout with 4 player positions
class TableLayout extends ConsumerWidget {
  final RoundState roundState;

  const TableLayout({super.key, required this.roundState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final southPlayer = roundState.playerAt(Seat.south);
    final westPlayer = roundState.playerAt(Seat.west);
    final northPlayer = roundState.playerAt(Seat.north);
    final eastPlayer = roundState.playerAt(Seat.east);

    final showSouthCards = ref.watch(shouldShowCardsProvider(Seat.south));
    final showWestCards = ref.watch(shouldShowCardsProvider(Seat.west));
    final showNorthCards = ref.watch(shouldShowCardsProvider(Seat.north));
    final showEastCards = ref.watch(shouldShowCardsProvider(Seat.east));

    return Container(
      color: Colors.green.shade800,
      child: Stack(
        children: [
          // South player (bottom - human)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: _PlayerPosition(
              player: southPlayer,
              position: PlayerPosition.bottom,
              showCards: showSouthCards,
            ),
          ),

          // West player (left)
          Positioned(
            left: 16,
            top: 0,
            bottom: 0,
            child: Center(
              child: _PlayerPosition(
                player: westPlayer,
                position: PlayerPosition.left,
                showCards: showWestCards,
              ),
            ),
          ),

          // North player (top - partner)
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: _PlayerPosition(
              player: northPlayer,
              position: PlayerPosition.top,
              showCards: showNorthCards,
            ),
          ),

          // East player (right)
          Positioned(
            right: 16,
            top: 0,
            bottom: 0,
            child: Center(
              child: _PlayerPosition(
                player: eastPlayer,
                position: PlayerPosition.right,
                showCards: showEastCards,
              ),
            ),
          ),

          // Center trick area
          Center(
            child: _TrickArea(roundState: roundState),
          ),

          // Trump indicator (top center)
          if (roundState.trumpSuit != null)
            Positioned(
              top: 120,
              left: 0,
              right: 0,
              child: Center(
                child: TrumpIndicator(
                  trumpSuit: roundState.trumpSuit,
                  trumpMakingTeam: roundState.trumpMakingTeam,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum PlayerPosition { top, bottom, left, right }

class _PlayerPosition extends StatelessWidget {
  final Player player;
  final PlayerPosition position;
  final bool showCards;

  const _PlayerPosition({
    required this.player,
    required this.position,
    required this.showCards,
  });

  @override
  Widget build(BuildContext context) {
    final isHorizontal = position == PlayerPosition.top || position == PlayerPosition.bottom;
    final animationDelay = _getAnimationDelay();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Player name
        Text(
          player.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        // Player's hand
        if (position == PlayerPosition.bottom)
          CardHand(
            cards: player.hand,
            isVisible: showCards,
          )
        else if (showCards)
          CardHand(
            cards: player.hand,
            isVisible: true,
          )
        else
          // Show card backs for other players
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              player.hand.length,
              (index) => const Padding(
                padding: EdgeInsets.only(right: 4),
                child: PlayingCardWidget(
                  card: null, // null shows back
                  size: CardSize.small,
                ),
              ),
            ),
          ),
      ],
    )
        .animate()
        .fadeIn(
          duration: const Duration(milliseconds: 400),
          delay: animationDelay,
        )
        .slideY(
          begin: 0.2,
          end: 0.0,
          duration: const Duration(milliseconds: 400),
          delay: animationDelay,
          curve: Curves.easeOut,
        );
  }

  Duration _getAnimationDelay() {
    switch (position) {
      case PlayerPosition.bottom:
        return const Duration(milliseconds: 0);
      case PlayerPosition.left:
        return const Duration(milliseconds: 100);
      case PlayerPosition.top:
        return const Duration(milliseconds: 200);
      case PlayerPosition.right:
        return const Duration(milliseconds: 300);
    }
  }
}

class _TrickArea extends StatelessWidget {
  final RoundState roundState;

  const _TrickArea({required this.roundState});

  @override
  Widget build(BuildContext context) {
    final trick = roundState.currentTrick;

    if (trick == null || trick.isEmpty) {
      return Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.green.shade700,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 2),
        ),
        child: const Center(
          child: Text(
            'Trick Area',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    // Show cards played in current trick with animation
    final playOrder = <Seat, int>{};
    int orderIndex = 0;
    for (final seat in trick.cardsPlayed.keys) {
      playOrder[seat] = orderIndex++;
    }

    return Container(
      width: 200,
      height: 200,
      child: Stack(
        children: trick.cardsPlayed.entries.map((entry) {
          final offset = _getCardOffset(entry.key);
          return _AnimatedTrickCard(
            card: entry.value as game_card.Card,
            position: offset,
            playOrder: playOrder[entry.key] ?? 0,
          );
        }).toList(),
      ),
    );
  }

  Offset _getCardOffset(Seat seat) {
    switch (seat) {
      case Seat.south:
        return const Offset(70, 140);
      case Seat.west:
        return const Offset(10, 70);
      case Seat.north:
        return const Offset(70, 10);
      case Seat.east:
        return const Offset(130, 70);
    }
  }
}

/// Animation wrapper for trick area cards
class _AnimatedTrickCard extends StatelessWidget {
  final game_card.Card card;
  final Offset position;
  final int playOrder;

  const _AnimatedTrickCard({
    required this.card,
    required this.position,
    required this.playOrder,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: PlayingCardWidget(
        card: card,
        size: CardSize.medium,
      )
          .animate()
          .fadeIn(
            duration: const Duration(milliseconds: 200),
            delay: Duration(milliseconds: 100 * playOrder),
          )
          .scale(
            begin: const Offset(0.8, 0.8),
            end: const Offset(1.0, 1.0),
            duration: const Duration(milliseconds: 300),
            delay: Duration(milliseconds: 100 * playOrder),
            curve: Curves.easeOutBack,
          ),
    );
  }
}
