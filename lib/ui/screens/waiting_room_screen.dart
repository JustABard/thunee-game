import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/lobby.dart';
import '../../domain/models/player.dart';
import '../../state/providers/lobby_provider.dart';
import '../../state/providers/local_seat_provider.dart';
import '../../state/providers/game_state_provider.dart';
import 'game_table_screen.dart';

/// Waiting room screen — shows lobby code, seated players, and start button.
class WaitingRoomScreen extends ConsumerStatefulWidget {
  const WaitingRoomScreen({super.key});

  @override
  ConsumerState<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends ConsumerState<WaitingRoomScreen> {
  bool _hasNavigated = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lobbyAsync = ref.watch(lobbyStreamProvider);
    final isHost = ref.watch(isHostProvider);

    // Auto-navigate when game starts
    ref.listen<AsyncValue<Lobby>>(lobbyStreamProvider, (prev, next) {
      final lobby = next.valueOrNull;
      if (lobby != null &&
          lobby.status == LobbyStatus.inProgress &&
          !_hasNavigated) {
        _hasNavigated = true;
        _navigateToGame(lobby);
      }
    });

    return Scaffold(
      body: SafeArea(
        child: lobbyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Error: $e',
                    style: TextStyle(color: theme.colorScheme.error)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back'),
                ),
              ],
            ),
          ),
          data: (lobby) => Column(
            children: [
              // Header with back button
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => _leaveLobby(lobby.code),
                    ),
                    Text('Waiting Room',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    // Lobby code — tap to copy
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: lobby.code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Code copied!'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              lobby.code,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 4,
                                color:
                                    theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.copy,
                                size: 18,
                                color:
                                    theme.colorScheme.onPrimaryContainer),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Seat grid
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: Seat.values.map((seat) {
                      final player = lobby.seats[seat];
                      return _SeatCard(
                        seat: seat,
                        player: player,
                        isLocalPlayer: player?.id ==
                            ref.read(localPlayerIdProvider),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Bottom bar
              Padding(
                padding: const EdgeInsets.all(12),
                child: isHost
                    ? ElevatedButton.icon(
                        onPressed: lobby.playerCount >= 1
                            ? () => _startGame(lobby)
                            : null,
                        icon: const Icon(Icons.play_arrow),
                        label: Text(
                          lobby.playerCount < 4
                              ? 'Start (bots fill empty seats)'
                              : 'Start Game',
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(200, 44),
                        ),
                      )
                    : Text(
                        'Waiting for host to start...',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withOpacity(0.6),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _leaveLobby(String code) async {
    final service = ref.read(firebaseLobbyServiceProvider);
    final playerId = ref.read(localPlayerIdProvider);
    await service.leaveLobby(code: code, playerId: playerId);
    ref.read(lobbyCodeProvider.notifier).state = null;
    if (mounted) Navigator.pop(context);
  }

  Future<void> _startGame(Lobby lobby) async {
    final service = ref.read(firebaseLobbyServiceProvider);

    // Set local seat to the host's seat
    for (final entry in lobby.seats.entries) {
      if (entry.value?.id == ref.read(localPlayerIdProvider)) {
        ref.read(localSeatProvider.notifier).state = entry.key;
        break;
      }
    }

    // Build player list (fill empty seats with bots)
    final players = <Player>[];
    for (final seat in Seat.values) {
      final lobbyPlayer = lobby.seats[seat];
      if (lobbyPlayer != null) {
        players.add(Player(
          id: lobbyPlayer.id,
          name: lobbyPlayer.name,
          seat: seat,
          hand: [],
          isBot: false,
        ));
      } else {
        final botNames = {
          Seat.south: 'Bot South',
          Seat.west: 'Bot West',
          Seat.north: 'Bot North',
          Seat.east: 'Bot East',
        };
        players.add(Player(
          id: 'bot_${seat.name}',
          name: botNames[seat]!,
          seat: seat,
          hand: [],
          isBot: true,
        ));
      }
    }

    // Start game via notifier
    ref.read(matchStateProvider.notifier).startNewMatch(players);

    // Mark lobby as in-progress
    await service.startGame(lobby.code);
  }

  void _navigateToGame(Lobby lobby) {
    // Set local seat for non-host players
    final playerId = ref.read(localPlayerIdProvider);
    for (final entry in lobby.seats.entries) {
      if (entry.value?.id == playerId) {
        ref.read(localSeatProvider.notifier).state = entry.key;
        break;
      }
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const GameTableScreen()),
    );
  }
}

// ── Seat card widget ─────────────────────────────────────────────────────────

class _SeatCard extends StatelessWidget {
  final Seat seat;
  final LobbyPlayer? player;
  final bool isLocalPlayer;

  const _SeatCard({
    required this.seat,
    required this.player,
    required this.isLocalPlayer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEmpty = player == null;

    return SizedBox(
      width: 120,
      child: Card(
        color: isLocalPlayer
            ? theme.colorScheme.primaryContainer
            : isEmpty
                ? theme.colorScheme.surfaceContainerHighest
                    .withOpacity(0.5)
                : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isEmpty
                    ? Icons.smart_toy_outlined
                    : (player!.isHost
                        ? Icons.star
                        : Icons.person),
                size: 28,
                color: isEmpty
                    ? theme.colorScheme.onSurface.withOpacity(0.3)
                    : theme.colorScheme.primary,
              ),
              const SizedBox(height: 6),
              Text(
                isEmpty ? 'Bot' : player!.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isEmpty
                      ? theme.colorScheme.onSurface.withOpacity(0.4)
                      : null,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                seat.name.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
              if (isLocalPlayer) ...[
                const SizedBox(height: 4),
                Text('(You)',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
