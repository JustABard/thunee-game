import 'package:flutter/material.dart';
import '../../../domain/models/card.dart' as game_card;

enum CardSize { small, medium, large }

/// Widget to display a playing card
class PlayingCardWidget extends StatelessWidget {
  final game_card.Card? card; // null shows card back
  final CardSize size;
  final VoidCallback? onTap;
  final bool isSelected;

  const PlayingCardWidget({
    super.key,
    this.card,
    this.size = CardSize.medium,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final dimensions = _getCardDimensions(size);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: dimensions.width,
        height: dimensions.height,
        decoration: BoxDecoration(
          color: card == null ? Colors.blue.shade900 : Colors.white,
          borderRadius: BorderRadius.circular(8),
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
            ? _buildCardBack()
            : _buildCardFront(card! as game_card.Card, dimensions.fontSize),
      ),
    );
  }

  Widget _buildCardBack() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade900,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(
          Icons.auto_awesome,
          color: Colors.white24,
          size: _getCardDimensions(size).fontSize,
        ),
      ),
    );
  }

  Widget _buildCardFront(game_card.Card card, double fontSize) {
    final isRed = card.suit.isRed;
    final color = isRed ? Colors.red : Colors.black;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top rank
          Text(
            card.rank.symbol,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const Spacer(),
          // Center suit
          Center(
            child: Text(
              card.suit.symbol,
              style: TextStyle(
                fontSize: fontSize * 1.5,
                color: color,
              ),
            ),
          ),
          const Spacer(),
          // Bottom rank (rotated)
          Align(
            alignment: Alignment.bottomRight,
            child: Transform.rotate(
              angle: 3.14159, // 180 degrees
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

  _CardDimensions _getCardDimensions(CardSize size) {
    switch (size) {
      case CardSize.small:
        return const _CardDimensions(width: 40, height: 60, fontSize: 12);
      case CardSize.medium:
        return const _CardDimensions(width: 60, height: 90, fontSize: 16);
      case CardSize.large:
        return const _CardDimensions(width: 80, height: 120, fontSize: 20);
    }
  }
}

class _CardDimensions {
  final double width;
  final double height;
  final double fontSize;

  const _CardDimensions({
    required this.width,
    required this.height,
    required this.fontSize,
  });
}
