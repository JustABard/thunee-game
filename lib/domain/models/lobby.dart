import 'package:equatable/equatable.dart';
import 'player.dart';
import 'game_config.dart';

/// Represents a player in the lobby (before game starts)
class LobbyPlayer extends Equatable {
  final String id;
  final String name;
  final Seat seat;
  final bool isHost;
  final bool isConnected;

  const LobbyPlayer({
    required this.id,
    required this.name,
    required this.seat,
    this.isHost = false,
    this.isConnected = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'seat': seat.name,
        'isHost': isHost,
        'isConnected': isConnected,
      };

  factory LobbyPlayer.fromJson(Map<String, dynamic> json) => LobbyPlayer(
        id: json['id'] as String,
        name: json['name'] as String,
        seat: Seat.values.byName(json['seat'] as String),
        isHost: json['isHost'] as bool? ?? false,
        isConnected: json['isConnected'] as bool? ?? true,
      );

  @override
  List<Object?> get props => [id, name, seat, isHost, isConnected];
}

/// Lobby status
enum LobbyStatus { waiting, inProgress, finished }

/// Represents a multiplayer lobby
class Lobby extends Equatable {
  final String code;
  final String hostId;
  final LobbyStatus status;
  final Map<Seat, LobbyPlayer?> seats;
  final GameConfig config;
  final int createdAt;

  const Lobby({
    required this.code,
    required this.hostId,
    this.status = LobbyStatus.waiting,
    required this.seats,
    required this.config,
    required this.createdAt,
  });

  /// Number of human players currently seated
  int get playerCount => seats.values.where((p) => p != null).length;

  /// Whether the lobby is full (4 players)
  bool get isFull => playerCount == 4;

  /// List of empty seats
  List<Seat> get emptySeats =>
      seats.entries.where((e) => e.value == null).map((e) => e.key).toList();

  Map<String, dynamic> toJson() => {
        'code': code,
        'hostId': hostId,
        'status': status.name,
        'config': config.toJson(),
        'createdAt': createdAt,
        'seats': seats.map((seat, player) =>
            MapEntry(seat.name, player?.toJson())),
      };

  factory Lobby.fromJson(Map<String, dynamic> json) {
    final seatsJson = json['seats'] as Map<String, dynamic>? ?? {};
    final seats = <Seat, LobbyPlayer?>{};
    for (final seat in Seat.values) {
      final playerJson = seatsJson[seat.name];
      seats[seat] = playerJson != null
          ? LobbyPlayer.fromJson(
              Map<String, dynamic>.from(playerJson as Map))
          : null;
    }

    return Lobby(
      code: json['code'] as String,
      hostId: json['hostId'] as String,
      status: LobbyStatus.values.byName(
          json['status'] as String? ?? 'waiting'),
      seats: seats,
      config: json['config'] != null
          ? GameConfig.fromJson(
              Map<String, dynamic>.from(json['config'] as Map))
          : const GameConfig(),
      createdAt: json['createdAt'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [code, hostId, status, seats, config, createdAt];
}
