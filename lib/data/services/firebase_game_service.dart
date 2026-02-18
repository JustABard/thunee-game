import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../../domain/models/game_action.dart';
import '../../domain/models/match_state.dart';
import '../../domain/models/player.dart';
import '../../domain/serialization/state_serializer.dart';

/// Service for syncing game state and actions via Firebase RTDB.
class FirebaseGameService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  /// Host: writes redacted game state + per-seat hands to Firebase.
  Future<void> syncGameState(String code, MatchState state) async {
    final gameRef = _db.child('lobbies/$code/game');

    // Write redacted state (no hands)
    final redacted = StateSerializer.redactedToJson(state);
    await gameRef.child('state').set(redacted);

    // Write each player's hand to their private path
    final hands = StateSerializer.handsToJson(state);
    for (final entry in hands.entries) {
      await gameRef.child('hands/${entry.key}').set(entry.value);
    }
  }

  /// Client: watches the redacted game state combined with own hand.
  /// Returns a stream of MatchState with the viewer's hand restored.
  Stream<MatchState> watchGameState(String code, Seat mySeat) {
    final stateRef = _db.child('lobbies/$code/game/state');
    final handRef = _db.child('lobbies/$code/game/hands/${mySeat.name}');

    // Combine state and hand streams
    return stateRef.onValue.asyncMap((stateEvent) async {
      if (stateEvent.snapshot.value == null) {
        throw Exception('No game state');
      }

      final stateJson = Map<String, dynamic>.from(
          stateEvent.snapshot.value as Map);
      final redactedState = MatchState.fromJson(stateJson);

      // Read own hand
      final handSnapshot = await handRef.get();
      if (handSnapshot.value != null) {
        final handList = (handSnapshot.value as List)
            .map((e) => e.toString())
            .toList();
        return StateSerializer.restoreHand(redactedState, mySeat, handList);
      }

      return redactedState;
    });
  }

  /// Client: submits an action to the action queue for the host to process.
  Future<void> submitAction(String code, GameAction action) async {
    await _db
        .child('lobbies/$code/game/actions')
        .push()
        .set(action.toJson());
  }

  /// Host: watches the action queue for new actions to process.
  /// Returns a stream of (key, GameAction) pairs.
  /// After processing, the host should call [removeAction] to clean up.
  Stream<MapEntry<String, GameAction>> watchActions(String code) {
    final actionsRef = _db.child('lobbies/$code/game/actions');

    return actionsRef.onChildAdded.map((event) {
      final key = event.snapshot.key!;
      final json = Map<String, dynamic>.from(event.snapshot.value as Map);
      return MapEntry(key, GameAction.fromJson(json));
    });
  }

  /// Host: removes a processed action from the queue.
  Future<void> removeAction(String code, String actionKey) async {
    await _db
        .child('lobbies/$code/game/actions/$actionKey')
        .remove();
  }

  /// Clears all game data for a lobby.
  Future<void> clearGameData(String code) async {
    await _db.child('lobbies/$code/game').remove();
  }
}
