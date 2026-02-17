import 'package:flutter/material.dart';
import '../../../domain/models/card.dart' as game_card;

enum CardSize { small, medium, large }

/// Widget to display a playing card.
///
/// Size can be specified via [size] enum (scales with screen height) or
/// overridden explicitly with [width] and [height].
class PlayingCardWidget extends StatelessWidget {
  final game_card.Card? card; // null shows card back
  final CardSize size;
  final double? width;  // explicit override — ignores [size] when set with [height]
  final double? height; // explicit override
  final VoidCallback? onTap;
  final bool isSelected;

  const PlayingCardWidget({
    super.key,
    this.card,
    this.size = CardSize.medium,
    this.width,
    this.height,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final dims = _getDimensions(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: dims.width,
        height: dims.height,
        decoration: BoxDecoration(
          color: card == null ? Colors.blue.shade900 : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? Colors.yellow : Colors.black26,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: card == null
            ? _buildCardBack(dims.fontSize)
            : _buildCardFront(card!, dims.fontSize),
      ),
    );
  }

  Widget _buildCardBack(double fontSize) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade900,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Icon(Icons.auto_awesome, color: Colors.white24, size: fontSize),
      ),
    );
  }

  Widget _buildCardFront(game_card.Card card, double fontSize) {
    final isRed = card.suit.isRed;
    final color = isRed ? Colors.red : Colors.black;

    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            card.rank.symbol,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const Spacer(),
          Center(
            child: Text(
              card.suit.symbol,
              style: TextStyle(fontSize: fontSize * 1.4, color: color),
            ),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.bottomRight,
            child: Transform.rotate(
              angle: 3.14159,
              child: Text(
                card.rank.symbol,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  _CardDims _getDimensions(BuildContext context) {
    // Explicit override takes priority
    if (width != null && height != null) {
      return _CardDims(width: width!, height: height!, fontSize: height! * 0.20);
    }

    // Scale from the shorter screen dimension (height in landscape)
    final screenH = MediaQuery.sizeOf(context).height;

    switch (size) {
      case CardSize.small:
        final h = (screenH * 0.15).clamp(38.0, 62.0);
        return _CardDims(width: h * 0.67, height: h, fontSize: h * 0.18);
      case CardSize.medium:
        final h = (screenH * 0.20).clamp(52.0, 88.0);
        return _CardDims(width: h * 0.67, height: h, fontSize: h * 0.20);
      case CardSize.large:
        final h = (screenH * 0.27).clamp(72.0, 112.0);
        return _CardDims(width: h * 0.67, height: h, fontSize: h * 0.22);
    }
  }
}

class _CardDims {
  final double width;
  final double height;
  final double fontSize;

  const _CardDims({
    required this.width,
    required this.height,
    required this.fontSize,
  });
}
