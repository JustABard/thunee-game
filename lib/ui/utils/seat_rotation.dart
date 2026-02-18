import '../../domain/models/player.dart';

/// Visual positions on screen — always relative to the local player's perspective.
enum VisualPosition { bottom, right, top, left }

/// Maps between absolute Seat values and screen VisualPositions
/// based on which seat the local player occupies.
///
/// The local player is always rendered at `bottom`. The remaining seats
/// follow anti-clockwise order: right, top, left.
class SeatRotation {
  final Seat localSeat;

  const SeatRotation(this.localSeat);

  /// Returns the absolute Seat that should be rendered at the given screen position.
  Seat absoluteSeatAt(VisualPosition pos) {
    // Number of anti-clockwise steps from south to localSeat
    Seat seat = localSeat;
    switch (pos) {
      case VisualPosition.bottom:
        return seat;
      case VisualPosition.right:
        return seat.next; // one step anti-clockwise
      case VisualPosition.top:
        return seat.next.next; // two steps (partner)
      case VisualPosition.left:
        return seat.next.next.next; // three steps
    }
  }

  /// Returns the screen position where the given absolute Seat should appear.
  VisualPosition visualPositionOf(Seat seat) {
    if (seat == localSeat) return VisualPosition.bottom;
    if (seat == localSeat.next) return VisualPosition.right;
    if (seat == localSeat.next.next) return VisualPosition.top;
    return VisualPosition.left;
  }
}
