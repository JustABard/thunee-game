import '../models/card.dart';
import '../models/match_state.dart';
import '../models/player.dart';

/// Utilities for serializing game state for Firebase sync.
///
/// The host writes a "redacted" state (no hands) plus per-seat hand paths
/// so each client can only read their own cards.
class StateSerializer {
  /// Returns a redacted JSON map of the match state.
  /// All player hands are replaced with empty lists; handSize is preserved
  /// so the UI can show the correct number of card backs.
  static Map<String, dynamic> redactedToJson(MatchState state) {
    final json = state.toJson();

    // Redact player hands in the top-level players list
    json['players'] = _redactPlayers(json['players'] as List);

    // Redact player hands in currentRound
    if (json['currentRound'] != null) {
      final round = Map<String, dynamic>.from(
          json['currentRound'] as Map<String, dynamic>);
      round['players'] = _redactPlayers(round['players'] as List);
      round['remainingCards'] = null;
      json['currentRound'] = round;
    }

    // Redact hands in completed rounds
    json['completedRounds'] = (json['completedRounds'] as List).map((r) {
      final rMap = Map<String, dynamic>.from(r as Map<String, dynamic>);
      rMap['players'] = _redactPlayers(rMap['players'] as List);
      rMap['remainingCards'] = null;
      return rMap;
    }).toList();

    return json;
  }

  static List<Map<String, dynamic>> _redactPlayers(List players) {
    return players.map((p) {
      final pMap = Map<String, dynamic>.from(p as Map<String, dynamic>);
      pMap['handSize'] = (pMap['hand'] as List).length;
      pMap['hand'] = <String>[];
      return pMap;
    }).toList();
  }

  /// Returns a map of seat name to serialized hand (list of card strings).
  /// Used by the host to write each player's hand to their private Firebase path.
  static Map<String, List<String>> handsToJson(MatchState state) {
    final hands = <String, List<String>>{};
    final round = state.currentRound;
    if (round == null) return hands;

    for (final player in round.players) {
      hands[player.seat.name] =
          player.hand.map((c) => c.toJson()).toList();
    }
    return hands;
  }

  /// Restores hand cards into a redacted MatchState for a specific seat.
  /// Used by clients after reading their own hand from Firebase.
  static MatchState restoreHand(
    MatchState redactedState,
    Seat viewerSeat,
    List<String> handJson,
  ) {
    final round = redactedState.currentRound;
    if (round == null) return redactedState;

    final cards = handJson.map((s) => Card.fromString(s)).toList();

    final updatedPlayers = round.players.map((p) {
      if (p.seat == viewerSeat) {
        return p.copyWith(hand: cards);
      }
      return p;
    }).toList();

    return redactedState.copyWith(
      currentRound: round.copyWith(players: updatedPlayers),
    );
  }
}
