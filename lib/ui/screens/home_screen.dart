import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'mode_select_screen.dart';
import 'settings_screen.dart';
import 'rules_screen.dart';

/// Home screen — cartoony card-themed landing with playful aesthetic.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF0D2137), // deep navy top
                    Color(0xFF132E4A), // mid blue
                    Color(0xFF0A1A2E), // dark base
                  ],
                ),
              ),
            ),
          ),

          // Scattered decorative cards (background)
          Positioned.fill(child: _buildScatteredCards()),

          // Main content
          SafeArea(
            child: Row(
              children: [
                // ── Left: Logo & branding ─────────────────────────────
                Expanded(
                  flex: 5,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Card fan behind logo
                        SizedBox(
                          height: 100,
                          width: 180,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Fan of 5 cards behind the title
                              for (int i = 0; i < 5; i++)
                                Positioned(
                                  child: Transform.rotate(
                                    angle: (i - 2) * 0.18,
                                    child: _MiniCard(
                                      suit: ['♠', '♥', '♦', '♣', '♥'][i],
                                      rank: ['J', '9', 'A', 'K', 'Q'][i],
                                      color: [
                                        Colors.white,
                                        const Color(0xFFFF4444),
                                        const Color(0xFFFF4444),
                                        Colors.white,
                                        const Color(0xFFFF4444),
                                      ][i],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Title
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              Color(0xFFFFD54F), // warm gold
                              Color(0xFFFFA726), // orange gold
                              Color(0xFFFFD54F), // warm gold
                            ],
                          ).createShader(bounds),
                          child: const Text(
                            'THUNEE',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 6,
                              shadows: [
                                Shadow(
                                  color: Color(0x80000000),
                                  blurRadius: 12,
                                  offset: Offset(2, 3),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Subtitle
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: const Text(
                            'South African Card Game',
                            style: TextStyle(
                              color: Color(0xAAFFFFFF),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Suit icons row
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final suit in ['♠', '♥', '♦', '♣'])
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: Text(
                                  suit,
                                  style: TextStyle(
                                    fontSize: 20,
                                    color: (suit == '♥' || suit == '♦')
                                        ? const Color(0xCCFF4444)
                                        : const Color(0xCCFFFFFF),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Right: Menu buttons ───────────────────────────────
                Expanded(
                  flex: 3,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _CardButton(
                          icon: Icons.play_arrow_rounded,
                          label: 'Play Game',
                          color: const Color(0xFF2E7D32),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ModeSelectScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _CardButton(
                          icon: Icons.settings_rounded,
                          label: 'Settings',
                          color: const Color(0xFF37474F),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _CardButton(
                          icon: Icons.menu_book_rounded,
                          label: 'How to Play',
                          color: const Color(0xFF4527A0),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RulesScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds scattered decorative card shapes in the background.
  Widget _buildScatteredCards() {
    final cards = <_ScatteredCardData>[
      _ScatteredCardData(left: 0.02, top: 0.08, angle: -0.3, opacity: 0.06),
      _ScatteredCardData(left: 0.85, top: 0.12, angle: 0.25, opacity: 0.05),
      _ScatteredCardData(left: 0.15, top: 0.75, angle: 0.15, opacity: 0.05),
      _ScatteredCardData(left: 0.75, top: 0.70, angle: -0.2, opacity: 0.06),
      _ScatteredCardData(left: 0.45, top: 0.02, angle: 0.1, opacity: 0.04),
      _ScatteredCardData(left: 0.55, top: 0.85, angle: -0.15, opacity: 0.04),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          children: cards.map((data) {
            return Positioned(
              left: w * data.left,
              top: h * data.top,
              child: Transform.rotate(
                angle: data.angle,
                child: Container(
                  width: 50,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: data.opacity),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: data.opacity * 0.8),
                      width: 1,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ScatteredCardData {
  final double left, top, angle, opacity;
  const _ScatteredCardData({
    required this.left,
    required this.top,
    required this.angle,
    required this.opacity,
  });
}

/// A mini playing card used in the decorative fan behind the title.
class _MiniCard extends StatelessWidget {
  final String suit;
  final String rank;
  final Color color;

  const _MiniCard({
    required this.suit,
    required this.rank,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 62,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E8),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0x40000000), width: 0.8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 6,
            offset: Offset(1, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            rank,
            style: TextStyle(
              color: color == Colors.white ? Colors.black87 : color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          Text(
            suit,
            style: TextStyle(
              color: color == Colors.white ? Colors.black87 : color,
              fontSize: 14,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// A menu button styled like a card with rounded edges and a colored gradient.
class _CardButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _CardButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  State<_CardButton> createState() => _CardButtonState();
}

class _CardButtonState extends State<_CardButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(widget.color, Colors.white, 0.15)!,
                widget.color,
                Color.lerp(widget.color, Colors.black, 0.15)!,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.3),
                blurRadius: _pressed ? 4 : 12,
                offset: Offset(0, _pressed ? 1 : 4),
              ),
              const BoxShadow(
                color: Color(0x40000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
