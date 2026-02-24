import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import '../../domain/models/game_config.dart';
import '../../domain/models/lobby.dart';
import '../../domain/models/player.dart';

/// Recursively converts a Firebase value (Map<Object?,Object?> / List) into
/// plain Dart types so fromJson methods receive Map<String,dynamic>.
dynamic _deepCast(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.fromEntries(
      value.entries.map((e) => MapEntry(e.key as String, _deepCast(e.value))),
    );
  }
  if (value is List) {
    return value.map(_deepCast).toList();
  }
  return value;
}

/// Service for creating, joining, and managing multiplayer lobbies via Firebase RTDB.
class FirebaseLobbyService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  static const _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no ambiguous I/O/0/1

  /// Generates a unique 6-character lobby code.
  String _generateCode() {
    final rng = Random.secure();
    return List.generate(6, (_) => _chars[rng.nextInt(_chars.length)]).join();
  }

  /// Creates a new lobby. The creator is seated at [seat] (default: south).
  Future<Lobby> createLobby({
    required String playerId,
    required String playerName,
    Seat seat = Seat.south,
    GameConfig config = const GameConfig(),
  }) async {
    // Generate code, retry if collision (unlikely)
    String code;
    DataSnapshot snapshot;
    do {
      code = _generateCode();
      snapshot = await _db.child('lobbies/$code').get();
    } while (snapshot.exists);

    final hostPlayer = LobbyPlayer(
      id: playerId,
      name: playerName,
      seat: seat,
      isHost: true,
    );

    final seats = <Seat, LobbyPlayer?>{};
    for (final s in Seat.values) {
      seats[s] = s == seat ? hostPlayer : null;
    }

    final lobby = Lobby(
      code: code,
      hostId: playerId,
      status: LobbyStatus.waiting,
      seats: seats,
      config: config,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    await _db.child('lobbies/$code').set(lobby.toJson());
    return lobby;
  }

  /// Joins an existing lobby. Claims the first empty seat atomically.
  /// Throws if lobby not found, already full, or player already in lobby.
  Future<Lobby> joinLobby({
    required String code,
    required String playerId,
    required String playerName,
  }) async {
    final lobbyRef = _db.child('lobbies/$code');
    final snapshot = await lobbyRef.get();

    if (!snapshot.exists) {
      throw Exception('Lobby not found: $code');
    }

    final lobby = Lobby.fromJson(
        _deepCast(snapshot.value) as Map<String, dynamic>);

    if (lobby.status != LobbyStatus.waiting) {
      throw Exception('Game already in progress');
    }

    // Check if player is already seated
    for (final entry in lobby.seats.entries) {
      if (entry.value?.id == playerId) {
        return lobby; // Already joined
      }
    }

    // Find first empty seat
    final emptySeats = lobby.emptySeats;
    if (emptySeats.isEmpty) {
      throw Exception('Lobby is full');
    }

    final seat = emptySeats.first;
    final newPlayer = LobbyPlayer(
      id: playerId,
      name: playerName,
      seat: seat,
    );

    await lobbyRef.child('seats/${seat.name}').set(newPlayer.toJson());

    // Return updated lobby
    final updatedSnapshot = await lobbyRef.get();
    return Lobby.fromJson(
        _deepCast(updatedSnapshot.value) as Map<String, dynamic>);
  }

  /// Removes a player from the lobby (clears their seat).
  Future<void> leaveLobby({
    required String code,
    required String playerId,
  }) async {
    final lobbyRef = _db.child('lobbies/$code');
    final snapshot = await lobbyRef.get();

    if (!snapshot.exists) return;

    final lobby = Lobby.fromJson(
        _deepCast(snapshot.value) as Map<String, dynamic>);

    for (final entry in lobby.seats.entries) {
      if (entry.value?.id == playerId) {
        await lobbyRef.child('seats/${entry.key.name}').remove();
        break;
      }
    }
  }

  /// Returns a real-time stream of lobby updates.
  Stream<Lobby> watchLobby(String code) {
    return _db.child('lobbies/$code').onValue.map((event) {
      if (event.snapshot.value == null) {
        throw Exception('Lobby deleted');
      }
      return Lobby.fromJson(
          _deepCast(event.snapshot.value) as Map<String, dynamic>);
    });
  }

  /// Transitions the lobby to in-progress. Called by the host.
  Future<void> startGame(String code) async {
    await _db.child('lobbies/$code/status').set('inProgress');
  }

  /// Deletes the lobby (cleanup).
  Future<void> deleteLobby(String code) async {
    await _db.child('lobbies/$code').remove();
  }

  /// Writes a heartbeat for a seat.
  Future<void> writeHeartbeat(String code, Seat seat) async {
    await _db
        .child('lobbies/$code/heartbeats/${seat.name}')
        .set(ServerValue.timestamp);
  }

  /// Sets up onDisconnect to clear the heartbeat when connection drops.
  Future<void> setupDisconnectHandler(String code, Seat seat) async {
    await _db
        .child('lobbies/$code/heartbeats/${seat.name}')
        .onDisconnect()
        .remove();
  }

  /// Returns a stream of heartbeat updates for monitoring.
  Stream<Map<Seat, int>> watchHeartbeats(String code) {
    return _db
        .child('lobbies/$code/heartbeats')
        .onValue
        .map((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return <Seat, int>{};
      return Map.fromEntries(
        data.entries.map((e) => MapEntry(
          Seat.values.byName(e.key as String),
          (e.value as int?) ?? 0,
        )),
      );
    });
  }
}
