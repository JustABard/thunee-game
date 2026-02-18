import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/player.dart';

/// The seat that the local player occupies.
/// Defaults to Seat.south for solo/pass-and-play modes.
/// Set to the assigned seat when joining a multiplayer lobby.
final localSeatProvider = StateProvider<Seat>((ref) => Seat.south);
