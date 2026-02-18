import 'package:equatable/equatable.dart';
import 'player.dart';

/// Types of actions that can be submitted in multiplayer
enum GameActionType {
  bid,
  pass,
  selectTrump,
  playCard,
  callThunee,
  callRoyals,
  callJodi,
  dismissCallWindow,
  dismissJodiWindow,
  dismissRoundResult,
}

/// Represents an action submitted by a player in multiplayer mode.
/// Clients push these to Firebase; the host processes them.
class GameAction extends Equatable {
  final GameActionType type;
  final Seat seat;
  final Map<String, dynamic> data;
  final String playerId;
  final int timestamp;

  const GameAction({
    required this.type,
    required this.seat,
    this.data = const {},
    required this.playerId,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'seat': seat.name,
        'data': data,
        'playerId': playerId,
        'timestamp': timestamp,
      };

  factory GameAction.fromJson(Map<String, dynamic> json) => GameAction(
        type: GameActionType.values.byName(json['type'] as String),
        seat: Seat.values.byName(json['seat'] as String),
        data: Map<String, dynamic>.from(
            json['data'] as Map? ?? {}),
        playerId: json['playerId'] as String,
        timestamp: json['timestamp'] as int? ?? 0,
      );

  @override
  List<Object?> get props => [type, seat, data, playerId, timestamp];
}
