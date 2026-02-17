import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../domain/models/card.dart' as game_card;
import 'playing_card_widget.dart';

/// Animation durations
class AnimationDurations {
  static const dealCard = Duration(milliseconds: 300);
  static const playCard = Duration(milliseconds: 400);
  static const collectTrick = Duration(milliseconds: 500);
  static const flipCard = Duration(milliseconds: 400);
  static const dealDelay = Duration(milliseconds: 100); // Stagger between cards
}

/// Animated card that deals from center to player position
class DealingCardAnimation extends StatelessWidget {
  final game_card.Card card;
  final Offset startPosition;
  final Offset endPosition;
  final int dealIndex; // For staggered animation
  final VoidCallback? onComplete;

  const DealingCardAnimation({
    super.key,
    required this.card,
    required this.startPosition,
    required this.endPosition,
    required this.dealIndex,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return PlayingCardWidget(
      card: null, // Show back during deal
      size: CardSize.medium,
    )
        .animate(
          onComplete: (_) => onComplete?.call(),
        )
        .move(
          begin: startPosition,
          end: endPosition,
          duration: AnimationDurations.dealCard,
          delay: AnimationDurations.dealDelay * dealIndex,
          curve: Curves.easeOutCubic,
        )
        .fadeIn(
          duration: const Duration(milliseconds: 200),
          delay: AnimationDurations.dealDelay * dealIndex,
        );
  }
}

/// Animated card playing from hand to trick area
class PlayingCardAnimation extends StatelessWidget {
  final game_card.Card card;
  final Offset startPosition;
  final Offset endPosition;
  final VoidCallback? onComplete;

  const PlayingCardAnimation({
    super.key,
    required this.card,
    required this.startPosition,
    required this.endPosition,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return PlayingCardWidget(
      card: card,
      size: CardSize.medium,
    )
        .animate(
          onComplete: (_) => onComplete?.call(),
        )
        .move(
          begin: startPosition,
          end: endPosition,
          duration: AnimationDurations.playCard,
          curve: Curves.easeInOut,
        )
        .scale(
          begin: const Offset(1.0, 1.0),
          end: const Offset(1.1, 1.1),
          duration: const Duration(milliseconds: 200),
        )
        .then()
        .scale(
          begin: const Offset(1.1, 1.1),
          end: const Offset(1.0, 1.0),
          duration: const Duration(milliseconds: 200),
        );
  }
}

/// Animated trick collection to winner
class CollectTrickAnimation extends StatelessWidget {
  final List<game_card.Card> cards;
  final Offset startPosition;
  final Offset endPosition;
  final VoidCallback? onComplete;

  const CollectTrickAnimation({
    super.key,
    required this.cards,
    required this.startPosition,
    required this.endPosition,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: cards.asMap().entries.map((entry) {
        final index = entry.key;
        final card = entry.value;

        return Positioned(
          left: startPosition.dx + (index * 5),
          top: startPosition.dy,
          child: PlayingCardWidget(
            card: card,
            size: CardSize.small,
          )
              .animate(
                onComplete: (_) {
                  if (index == cards.length - 1) {
                    onComplete?.call();
                  }
                },
              )
              .move(
                begin: Offset.zero,
                end: endPosition - startPosition,
                duration: AnimationDurations.collectTrick,
                delay: Duration(milliseconds: 50 * index),
                curve: Curves.easeInCubic,
              )
              .fadeOut(
                duration: const Duration(milliseconds: 200),
                delay: AnimationDurations.collectTrick - const Duration(milliseconds: 200),
              ),
        );
      }).toList(),
    );
  }
}

/// 3D flip animation for revealing blind cards
class FlipCardAnimation extends StatefulWidget {
  final game_card.Card? frontCard;
  final bool showFront;
  final CardSize size;
  final VoidCallback? onTap;

  const FlipCardAnimation({
    super.key,
    required this.frontCard,
    required this.showFront,
    this.size = CardSize.medium,
    this.onTap,
  });

  @override
  State<FlipCardAnimation> createState() => _FlipCardAnimationState();
}

class _FlipCardAnimationState extends State<FlipCardAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AnimationDurations.flipCard,
      vsync: this,
    );

    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.showFront) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(FlipCardAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showFront != oldWidget.showFront) {
      if (widget.showFront) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _flipAnimation,
      builder: (context, child) {
        final angle = _flipAnimation.value * 3.14159; // 180 degrees
        final showFront = _flipAnimation.value > 0.5;

        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // Perspective
            ..rotateY(angle),
          alignment: Alignment.center,
          child: showFront
              ? PlayingCardWidget(
                  card: widget.frontCard,
                  size: widget.size,
                  onTap: widget.onTap,
                )
              : Transform(
                  transform: Matrix4.identity()..rotateY(3.14159),
                  alignment: Alignment.center,
                  child: PlayingCardWidget(
                    card: null, // Back
                    size: widget.size,
                  ),
                ),
        );
      },
    );
  }
}

/// Pulse animation for highlighting legal cards
class PulseCardWidget extends StatelessWidget {
  final game_card.Card card;
  final bool isLegal;
  final CardSize size;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  /// Override shimmer colour (defaults to yellow for legal, green for trump-choosing)
  final Color? shimmerColor;

  const PulseCardWidget({
    super.key,
    required this.card,
    required this.isLegal,
    this.size = CardSize.medium,
    this.width,
    this.height,
    this.onTap,
    this.shimmerColor,
  });

  @override
  Widget build(BuildContext context) {
    final baseWidget = PlayingCardWidget(
      card: card,
      size: size,
      width: width,
      height: height,
      onTap: onTap,
      isSelected: false,
    );

    if (!isLegal) {
      return baseWidget.animate().fade(end: 0.5);
    }

    final color = shimmerColor ?? Colors.yellow.withOpacity(0.3);

    return baseWidget
        .animate(
          onPlay: (controller) => controller.repeat(reverse: true),
        )
        .shimmer(
          duration: const Duration(milliseconds: 1500),
          color: color,
        );
  }
}

/// Slide-in animation for bidding panel
class SlidingPanel extends StatelessWidget {
  final Widget child;
  final bool isVisible;

  const SlidingPanel({
    super.key,
    required this.child,
    required this.isVisible,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: isVisible ? null : 0,
      child: child,
    ).animate().slideY(
          begin: 1.0,
          end: 0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
  }
}

/// Bounce animation for score changes
class BounceScore extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final bool shouldBounce;

  const BounceScore({
    super.key,
    required this.text,
    this.style,
    this.shouldBounce = false,
  });

  @override
  Widget build(BuildContext context) {
    final textWidget = Text(text, style: style);

    if (!shouldBounce) return textWidget;

    return textWidget
        .animate()
        .scale(
          begin: const Offset(1.0, 1.0),
          end: const Offset(1.3, 1.3),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        )
        .then()
        .scale(
          begin: const Offset(1.3, 1.3),
          end: const Offset(1.0, 1.0),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeIn,
        );
  }
}
