import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/player.dart';
import '../../state/providers/game_state_provider.dart';
import 'game_table_screen.dart';

/// Screen for selecting game mode (1 human vs 3 bots, or 2 humans vs 2 bots)
class ModeSelectScreen extends ConsumerWidget {
  const ModeSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Game Mode'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Choose Your Mode',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 48),

            // 1 Human + 3 Bots
            _ModeCard(
              title: 'Solo Play',
              description: '1 Human vs 3 Bots',
              icon: Icons.person,
              onTap: () => _startGame(context, ref, humanCount: 1),
            ),
            const SizedBox(height: 24),

            // 2 Humans + 2 Bots (Pass and Play)
            _ModeCard(
              title: 'Pass & Play',
              description: '2 Humans vs 2 Bots',
              icon: Icons.people,
              onTap: () => _startGame(context, ref, humanCount: 2),
            ),
          ],
        ),
      ),
    );
  }

  void _startGame(BuildContext context, WidgetRef ref, {required int humanCount}) {
    // Create players
    final players = [
      Player(
        id: '1',
        name: 'You',
        seat: Seat.south,
        hand: [],
        isBot: false,
      ),
      Player(
        id: '2',
        name: humanCount == 2 ? 'Player 2' : 'Bot West',
        seat: Seat.west,
        hand: [],
        isBot: humanCount == 1,
      ),
      Player(
        id: '3',
        name: 'Bot North',
        seat: Seat.north,
        hand: [],
        isBot: true,
      ),
      Player(
        id: '4',
        name: 'Bot East',
        seat: Seat.east,
        hand: [],
        isBot: true,
      ),
    ];

    // Start new match
    ref.read(matchStateProvider.notifier).startNewMatch(players);

    // Navigate to game table
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const GameTableScreen(),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
