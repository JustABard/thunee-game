import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../domain/models/card.dart' as game_card;
import '../../../domain/utils/card_sorter.dart';
import '../../../state/providers/game_state_provider.dart';
import 'playing_card_widget.dart';
import 'card_animations.dart';

/// Shuffle animation phase
enum _ShufflePhase { none, contracting, expanding }

/// Displays a hand of cards in a horizontal row.
///
/// - On initial deal: cards animate in from below with staggered timing.
/// - After deal completes (~1100ms), cards sort by suit with a shuffle animation.
/// - When a card is played: remaining cards stay sorted (no re-entrance anim).
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
  _ShufflePhase _shufflePhase = _ShufflePhase.none;
  List<game_card.Card>? _sortedCards;
  bool _isSorted = false;

  @override
  void initState() {
    super.initState();
    _isNewDeal = true;
    // Schedule sort for the initial deal
    if (widget.cards.isNotEmpty) {
      _scheduleSortAfterDeal();
    }
  }

  @override
  void didUpdateWidget(CardHand oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldLen = oldWidget.cards.length;
    final newLen = widget.cards.length;

    if (newLen > oldLen && oldLen <= 1) {
      // Cards went from 0-1 to many — fresh deal
      _isNewDeal = true;
      _isSorted = false;
      _sortedCards = null;
      _shufflePhase = _ShufflePhase.none;
      _scheduleSortAfterDeal();
    } else if (newLen > oldLen && oldLen > 1) {
      // Cards increased mid-round (e.g. 4→6 after trump selection)
      // Show all cards immediately sorted, with a quick shuffle animation
      _isNewDeal = false;
      _sortedCards = null;
      _isSorted = false;
      _shufflePhase = _ShufflePhase.none;
      _scheduleSortAfterDeal(delay: 300);
    } else if (newLen < oldLen) {
      // Card count decreased — card was played, re-sort without animation
      _isNewDeal = false;
      if (_isSorted) {
        _sortedCards = sortHandBySuit(widget.cards);
      }
    } else if (newLen == oldLen && newLen > 0) {
      final changed = !_sameCards(oldWidget.cards, widget.cards);
      if (changed) {
        // Different cards with same count — new round
        _isNewDeal = true;
        _isSorted = false;
        _sortedCards = null;
        _shufflePhase = _ShufflePhase.none;
        _scheduleSortAfterDeal();
      }
    }
  }

  void _scheduleSortAfterDeal({int delay = 1200}) {
    // Wait for deal animation to complete, then trigger shuffle sort
    Future.delayed(Duration(milliseconds: delay), () {
      if (!mounted) return;
      if (widget.cards.isEmpty) return;
      setState(() {
        _shufflePhase = _ShufflePhase.contracting;
      });
      // Contract phase: 200ms
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        setState(() {
          _sortedCards = sortHandBySuit(widget.cards);
          _isSorted = true;
          _shufflePhase = _ShufflePhase.expanding;
        });
        // Expand phase: 350ms, then done
        Future.delayed(const Duration(milliseconds: 350), () {
          if (!mounted) return;
          setState(() {
            _shufflePhase = _ShufflePhase.none;
            _isNewDeal = false;
          });
        });
      });
    });
  }

  bool _sameCards(List<game_card.Card> a, List<game_card.Card> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// The cards to display — sorted if available, otherwise raw.
  List<game_card.Card> get _displayCards => _sortedCards ?? widget.cards;

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) return const SizedBox.shrink();

    final ch = widget.cardHeight ??
        (MediaQuery.sizeOf(context).height * 0.27).clamp(72.0, 112.0);
    final cw = ch * 0.67;

    final legalCards = ref.watch(legalCardsProvider);
    final isHumanTurn = ref.watch(isHumanTurnProvider);
    final isChoosingTrump = ref.watch(isChoosingTrumpProvider);

    // Determine shuffle transform values
    double shuffleScale = 1.0;
    double shuffleRotation = 0.0;
    Curve shuffleCurve = Curves.easeOutBack;
    Duration shuffleDuration = const Duration(milliseconds: 350);

    if (_shufflePhase == _ShufflePhase.contracting) {
      shuffleScale = 0.75;
      shuffleRotation = 0.02;
      shuffleCurve = Curves.easeIn;
      shuffleDuration = const Duration(milliseconds: 200);
    } else if (_shufflePhase == _ShufflePhase.expanding) {
      shuffleScale = 1.0;
      shuffleRotation = 0.0;
      shuffleCurve = Curves.easeOutBack;
      shuffleDuration = const Duration(milliseconds: 350);
    }

    final displayCards = _displayCards;

    return SizedBox(
      height: ch,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.center,
            children: [
              ...previousChildren,
              ?currentChild,
            ],
          );
        },
        child: Row(
          key: ValueKey(widget.cards.length),
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

            // Wrap in shuffle animation if active
            if (_shufflePhase != _ShufflePhase.none) {
              cardWidget = AnimatedScale(
                scale: shuffleScale,
                duration: shuffleDuration,
                curve: shuffleCurve,
                child: AnimatedRotation(
                  turns: shuffleRotation,
                  duration: shuffleDuration,
                  curve: shuffleCurve,
                  child: cardWidget,
                ),
              );
            }

            // Only apply entrance animation on new deal
            if (_isNewDeal && _shufflePhase == _ShufflePhase.none) {
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
      ),
    );
  }

  double _fanAngle(int index, int total) {
    if (total <= 1) return 0;
    final mid = (total - 1) / 2.0;
    return (index - mid) / total;
  }
}
