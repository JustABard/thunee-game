import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/player.dart';
import '../../state/providers/game_state_provider.dart';
import '../../state/providers/lobby_provider.dart';
import 'game_table_screen.dart';
import 'online_lobby_screen.dart';

/// Screen for selecting game mode — landscape-optimised side-by-side layout.
class ModeSelectScreen extends ConsumerWidget {
  const ModeSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Header row with back button and title ────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    'Select Game Mode',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),

            // ── Two mode cards side by side ──────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _ModeCard(
                        title: 'Solo Play',
                        description: '1 Human vs 3 Bots',
                        icon: Icons.person,
                        onTap: () => _startGame(context, ref, humanCount: 1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ModeCard(
                        title: 'Pass & Play',
                        description: '2 Humans vs 2 Bots',
                        icon: Icons.people,
                        onTap: () => _startGame(context, ref, humanCount: 2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ModeCard(
                        title: 'Online Play',
                        description: 'Up to 4 humans online',
                        icon: Icons.wifi,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const OnlineLobbyScreen()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startGame(BuildContext context, WidgetRef ref,
      {required int humanCount}) {
    ref.read(gameModeProvider.notifier).state =
        humanCount == 1 ? GameMode.solo : GameMode.passAndPlay;
    final players = [
      Player(id: '1', name: 'You', seat: Seat.south, hand: [], isBot: false),
      Player(
        id: '2',
        name: humanCount == 2 ? 'Player 2' : 'Bot West',
        seat: Seat.west,
        hand: [],
        isBot: humanCount == 1,
      ),
      Player(id: '3', name: 'Bot North', seat: Seat.north, hand: [], isBot: true),
      Player(id: '4', name: 'Bot East', seat: Seat.east, hand: [], isBot: true),
    ];

    ref.read(matchStateProvider.notifier).startNewMatch(players);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const GameTableScreen()),
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
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
