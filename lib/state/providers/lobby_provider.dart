import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/firebase_lobby_service.dart';
import '../../data/services/firebase_game_service.dart';
import '../../domain/models/lobby.dart';

/// Persistent player ID (set in main.dart via override)
final localPlayerIdProvider = Provider<String>((ref) {
  throw UnimplementedError('Must be overridden in main()');
});

/// Current lobby code (null = not in a lobby)
final lobbyCodeProvider = StateProvider<String?>((ref) => null);

/// Game mode: solo, passAndPlay, or online
enum GameMode { solo, passAndPlay, online }

final gameModeProvider = StateProvider<GameMode>((ref) => GameMode.solo);

/// Firebase lobby service (singleton)
final firebaseLobbyServiceProvider = Provider<FirebaseLobbyService>((ref) {
  return FirebaseLobbyService();
});

/// Firebase game service (singleton)
final firebaseGameServiceProvider = Provider<FirebaseGameService>((ref) {
  return FirebaseGameService();
});

/// Stream of lobby updates (active when lobbyCode is set)
final lobbyStreamProvider = StreamProvider<Lobby>((ref) {
  final code = ref.watch(lobbyCodeProvider);
  if (code == null) return const Stream.empty();

  final service = ref.watch(firebaseLobbyServiceProvider);
  return service.watchLobby(code);
});

/// Whether the local player is the host
final isHostProvider = Provider<bool>((ref) {
  final lobby = ref.watch(lobbyStreamProvider).valueOrNull;
  if (lobby == null) return false;

  final playerId = ref.watch(localPlayerIdProvider);
  return lobby.hostId == playerId;
});
