import '../models/call_type.dart';
import '../models/card.dart';
import '../models/round_state.dart';
import '../models/player.dart';

/// Decision made by a bot
abstract class BotDecision {}

/// Bot decides to play a card
class PlayCardDecision extends BotDecision {
  final Card card;

  PlayCardDecision(this.card);

  @override
  String toString() => 'PlayCard($card)';
}

/// Bot decides to make a bid
class MakeBidDecision extends BotDecision {
  final int amount;

  MakeBidDecision(this.amount);

  @override
  String toString() => 'MakeBid($amount)';
}

/// Bot decides to pass on bidding
class PassBidDecision extends BotDecision {
  @override
  String toString() => 'PassBid';
}

/// Bot decides to make a special call
class MakeSpecialCallDecision extends BotDecision {
  final CallData call;

  MakeSpecialCallDecision(this.call);

  @override
  String toString() => 'MakeSpecialCall(${call.category})';
}

/// Interface for bot decision-making strategies
abstract class BotPolicy {
  /// Decides which card to play
  PlayCardDecision decideCardPlay({
    required RoundState state,
    required Player bot,
    required List<Card> legalCards,
  });

  /// Decides whether to bid and how much
  BotDecision decideBid({
    required RoundState state,
    required Player bot,
  });

  /// Decides whether to make a special call
  BotDecision? decideSpecialCall({
    required RoundState state,
    required Player bot,
  });
}
