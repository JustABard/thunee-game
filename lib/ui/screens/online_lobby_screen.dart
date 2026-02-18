import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/providers/lobby_provider.dart';
import 'waiting_room_screen.dart';

/// Screen for creating or joining an online lobby.
class OnlineLobbyScreen extends ConsumerStatefulWidget {
  const OnlineLobbyScreen({super.key});

  @override
  ConsumerState<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends ConsumerState<OnlineLobbyScreen> {
  final _nameController = TextEditingController(text: 'Player');
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _createGame() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your name');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ref.read(firebaseLobbyServiceProvider);
      final playerId = ref.read(localPlayerIdProvider);

      final lobby = await service.createLobby(
        playerId: playerId,
        playerName: name,
      );

      ref.read(lobbyCodeProvider.notifier).state = lobby.code;
      ref.read(gameModeProvider.notifier).state = GameMode.online;

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const WaitingRoomScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to create lobby: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _joinGame() async {
    final name = _nameController.text.trim();
    final code = _codeController.text.trim().toUpperCase();

    if (name.isEmpty) {
      setState(() => _error = 'Please enter your name');
      return;
    }
    if (code.length != 6) {
      setState(() => _error = 'Enter a 6-character lobby code');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ref.read(firebaseLobbyServiceProvider);
      final playerId = ref.read(localPlayerIdProvider);

      await service.joinLobby(
        code: code,
        playerId: playerId,
        playerName: name,
      );

      ref.read(lobbyCodeProvider.notifier).state = code;
      ref.read(gameModeProvider.notifier).state = GameMode.online;

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const WaitingRoomScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    'Online Play',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Row(
                  children: [
                    // Name field (shared)
                    SizedBox(
                      width: 160,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Your Name',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            textCapitalization: TextCapitalization.words,
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              style: TextStyle(
                                color: theme.colorScheme.error,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Create game card
                    Expanded(
                      child: Card(
                        child: InkWell(
                          onTap: _isLoading ? null : _createGame,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_circle_outline,
                                    size: 36,
                                    color: theme.colorScheme.primary),
                                const SizedBox(height: 8),
                                Text('Create Game',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('Host a new lobby',
                                    style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Join game card
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.group_add_outlined,
                                  size: 36,
                                  color: theme.colorScheme.primary),
                              const SizedBox(height: 8),
                              Text('Join Game',
                                  style: theme.textTheme.titleMedium
                                      ?.copyWith(
                                          fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: 140,
                                child: TextField(
                                  controller: _codeController,
                                  decoration: const InputDecoration(
                                    labelText: 'Lobby Code',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  maxLength: 6,
                                ),
                              ),
                              const SizedBox(height: 4),
                              ElevatedButton(
                                onPressed: _isLoading ? null : _joinGame,
                                child: const Text('Join'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_isLoading) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
