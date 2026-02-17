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

/// Main game table — responsive Column/Row grid that scales with screen size.
///
/// Layout (landscape):
///   ┌────────────────────────────────────┐  ← northFrac of height
///   │               North                │
///   ├───────┬────────────────────┬───────┤
///   │ West  │    Trick area      │ East  │  ← remaining center height
///   ├───────┴────────────────────┴───────┤
///   │              South                 │  ← southFrac of height
///   └────────────────────────────────────┘
class TableLayout extends ConsumerWidget {
  final RoundState roundState;

  const TableLayout({super.key, required this.roundState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final southPlayer = roundState.playerAt(Seat.south);
    final westPlayer  = roundState.playerAt(Seat.west);
    final northPlayer = roundState.playerAt(Seat.north);
    final eastPlayer  = roundState.playerAt(Seat.east);

    final showSouth = ref.watch(shouldShowCardsProvider(Seat.south));
    final showWest  = ref.watch(shouldShowCardsProvider(Seat.west));
    final showNorth = ref.watch(shouldShowCardsProvider(Seat.north));
    final showEast  = ref.watch(shouldShowCardsProvider(Seat.east));

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        // Row/column fractions — sized conservatively so nothing overflows
        const northFrac = 0.18;
        const southFrac = 0.26;
        const sideFrac  = 0.10; // fraction of width for each side column

        final northH = h * northFrac;
        final southH = h * southFrac;
        final centerH = h - northH - southH;
        final sideW   = w * sideFrac;
        final centerW = w - sideW * 2;

        // Card heights derived from zone — clamped conservatively to leave room
        // for the player name label (≈14px) and the 3px spacer in _HorizontalPlayer
        final southCardH = (southH - 22).clamp(44.0, 68.0);
        final northCardH = (northH - 16).clamp(28.0, 44.0);
        final sideCardH  = (centerH * 0.20).clamp(24.0, 42.0);
        final trickCardH = (centerH * 0.32).clamp(38.0, 68.0);

        return Container(
          color: Colors.green.shade800,
          child: Stack(
            children: [
              Column(
                children: [
                  // ── North player ──────────────────────────────────────
                  SizedBox(
                    height: northH,
                    width: w,
                    child: Center(
                      child: _HorizontalPlayer(
                        player: northPlayer,
                        showCards: showNorth,
                        cardHeight: northCardH,
                        isTop: true,
                        animDelay: const Duration(milliseconds: 200),
                      ),
                    ),
                  ),

                  // ── Center row ────────────────────────────────────────
                  SizedBox(
                    height: centerH,
                    child: Row(
                      children: [
                        // West
                        SizedBox(
                          width: sideW,
                          height: centerH,
                          child: Center(
                            child: _SidePlayer(
                              player: westPlayer,
                              showCards: showWest,
                              cardH: sideCardH,
                              animDelay: const Duration(milliseconds: 100),
                            ),
                          ),
                        ),

                        // Trick area
                        SizedBox(
                          width: centerW,
                          height: centerH,
                          child: Center(
                            child: _TrickArea(
                              roundState: roundState,
                              trickCardH: trickCardH,
                              areaSize: (centerH * 0.78).clamp(80.0, 200.0),
                            ),
                          ),
                        ),

                        // East
                        SizedBox(
                          width: sideW,
                          height: centerH,
                          child: Center(
                            child: _SidePlayer(
                              player: eastPlayer,
                              showCards: showEast,
                              cardH: sideCardH,
                              animDelay: const Duration(milliseconds: 300),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── South player ──────────────────────────────────────
                  SizedBox(
                    height: southH,
                    width: w,
                    child: Center(
                      child: _HorizontalPlayer(
                        player: southPlayer,
                        showCards: showSouth,
                        cardHeight: southCardH,
                        isTop: false,
                        animDelay: Duration.zero,
                      ),
                    ),
                  ),
                ],
              ),

              // Trump indicator — overlaid in upper-center of trick area
              if (roundState.trumpSuit != null)
                Positioned(
                  top: northH + 4,
                  left: sideW,
                  right: sideW,
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
      },
    );
  }
}

// ── Horizontal player (North / South) ──────────────────────────────────────

class _HorizontalPlayer extends StatelessWidget {
  final Player player;
  final bool showCards;
  final double cardHeight;
  final bool isTop;
  final Duration animDelay;

  const _HorizontalPlayer({
    required this.player,
    required this.showCards,
    required this.cardHeight,
    required this.isTop,
    required this.animDelay,
  });

  @override
  Widget build(BuildContext context) {
    final nameLabel = Text(
      player.name,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 11,
      ),
    );

    final cardRow = showCards
        ? CardHand(cards: player.hand, isVisible: true, cardHeight: cardHeight)
        : _BackRow(count: player.hand.length, cardH: cardHeight, cardW: cardHeight * 0.67);

    final children = isTop
        ? [nameLabel, const SizedBox(height: 3), cardRow]
        : [cardRow, const SizedBox(height: 3), nameLabel];

    return ClipRect(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      )
          .animate()
          .fadeIn(duration: const Duration(milliseconds: 400), delay: animDelay)
          .slideY(
            begin: isTop ? -0.2 : 0.2,
            end: 0,
            duration: const Duration(milliseconds: 400),
            delay: animDelay,
            curve: Curves.easeOut,
          ),
    );
  }
}

// ── Side player (West / East) — vertical stack of backs ────────────────────

class _SidePlayer extends StatelessWidget {
  final Player player;
  final bool showCards;
  final double cardH;
  final Duration animDelay;

  const _SidePlayer({
    required this.player,
    required this.showCards,
    required this.cardH,
    required this.animDelay,
  });

  @override
  Widget build(BuildContext context) {
    final cardW = cardH * 0.67;
    final count = player.hand.length;
    // Overlap cards vertically so they fit in limited side width
    const overlapOffset = 10.0;
    final stackH = (count - 1) * overlapOffset + cardH;

    return ClipRect(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            player.name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          SizedBox(
            width: cardW,
            height: stackH,
            child: Stack(
              children: List.generate(count, (i) {
                final card = showCards && i < player.hand.length
                    ? player.hand[i]
                    : null;
                return Positioned(
                  top: i * overlapOffset,
                  child: PlayingCardWidget(
                    card: card,
                    width: cardW,
                    height: cardH,
                  ),
                );
              }),
            ),
          ),
        ],
      )
          .animate()
          .fadeIn(duration: const Duration(milliseconds: 400), delay: animDelay)
          .slideX(
            begin: -0.2,
            end: 0,
            duration: const Duration(milliseconds: 400),
            delay: animDelay,
            curve: Curves.easeOut,
          ),
    );
  }
}

// ── A row of face-down card backs ──────────────────────────────────────────

class _BackRow extends StatelessWidget {
  final int count;
  final double cardH;
  final double cardW;

  const _BackRow({required this.count, required this.cardH, required this.cardW});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) => Padding(
        padding: EdgeInsets.only(left: i > 0 ? 3 : 0),
        child: PlayingCardWidget(card: null, width: cardW, height: cardH),
      )),
    );
  }
}

// ── Trick area ─────────────────────────────────────────────────────────────

class _TrickArea extends StatelessWidget {
  final RoundState roundState;
  final double trickCardH;
  final double areaSize;

  const _TrickArea({
    required this.roundState,
    required this.trickCardH,
    required this.areaSize,
  });

  @override
  Widget build(BuildContext context) {
    final trick = roundState.currentTrick;
    final trickCardW = trickCardH * 0.67;

    if (trick == null || trick.isEmpty) {
      return Container(
        width: areaSize,
        height: areaSize,
        decoration: BoxDecoration(
          color: Colors.green.shade700,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 2),
        ),
        child: const Center(
          child: Text('Trick Area', style: TextStyle(color: Colors.white54, fontSize: 11)),
        ),
      );
    }

    // Cards fanned slightly around the center of the area
    return SizedBox(
      width: areaSize,
      height: areaSize,
      child: Stack(
        children: trick.cardsPlayed.entries.map((entry) {
          final offset = _cardOffset(entry.key, areaSize, trickCardW, trickCardH);
          final playOrder = trick.cardsPlayed.keys.toList().indexOf(entry.key);

          return Positioned(
            left: offset.dx,
            top: offset.dy,
            child: PlayingCardWidget(
              card: entry.value as game_card.Card,
              width: trickCardW,
              height: trickCardH,
            )
                .animate()
                .fadeIn(
                  duration: const Duration(milliseconds: 200),
                  delay: Duration(milliseconds: 80 * playOrder),
                )
                .scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1.0, 1.0),
                  duration: const Duration(milliseconds: 250),
                  delay: Duration(milliseconds: 80 * playOrder),
                  curve: Curves.easeOutBack,
                ),
          );
        }).toList(),
      ),
    );
  }

  /// Returns the top-left position for each seat's card in the trick area.
  Offset _cardOffset(Seat seat, double area, double cw, double ch) {
    final cx = area / 2 - cw / 2;
    final cy = area / 2 - ch / 2;
    const gap = 0.28; // fraction of half-area to offset each card
    switch (seat) {
      case Seat.south: return Offset(cx, cy + area * gap);
      case Seat.north: return Offset(cx, cy - area * gap);
      case Seat.west:  return Offset(cx - area * gap, cy);
      case Seat.east:  return Offset(cx + area * gap, cy);
    }
  }
}
