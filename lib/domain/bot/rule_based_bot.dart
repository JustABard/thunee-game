import '../models/card.dart';
import '../models/game_config.dart';
import '../models/player.dart';
import '../models/round_state.dart';
import '../rules/card_ranker.dart';
import '../rules/trick_resolver.dart';
import 'bot_policy.dart';
import 'call_decision_maker.dart';
import 'card_selector.dart';

/// A rule-based bot implementation that follows game rules and basic strategy.
///
/// Strategy:
/// - Follows suit when required
/// - Tries to win tricks when opponent is winning
/// - Dumps weak cards when partner is winning
/// - NEVER cuts partner during Thunee/Royals
/// - Bids using Hand Control Confidence model (HCC)
class RuleBasedBot implements BotPolicy {
  final CardSelector _cardSelector;
  final CallDecisionMaker _callDecisionMaker;

  RuleBasedBot({GameConfig config = const GameConfig()})
      : _cardSelector = CardSelector(CardRanker(), TrickResolver(CardRanker())),
        _callDecisionMaker = CallDecisionMaker(config);

  /// Factory constructor for custom dependencies (useful for testing)
  factory RuleBasedBot.withDependencies({
    required CardSelector cardSelector,
    required CallDecisionMaker callDecisionMaker,
  }) {
    return RuleBasedBot._internal(cardSelector, callDecisionMaker);
  }

  RuleBasedBot._internal(this._cardSelector, this._callDecisionMaker);

  @override
  PlayCardDecision decideCardPlay({
    required RoundState state,
    required Player bot,
    required List<Card> legalCards,
  }) {
    final selectedCard = _cardSelector.selectCard(
      state: state,
      bot: bot,
      legalCards: legalCards,
    );

    return PlayCardDecision(selectedCard);
  }

  @override
  BotDecision decideBid({
    required RoundState state,
    required Player bot,
  }) {
    return _callDecisionMaker.decideBid(state: state, bot: bot);
  }

  @override
  BotDecision? decideSpecialCall({
    required RoundState state,
    required Player bot,
  }) {
    return _callDecisionMaker.decideSpecialCall(state: state, bot: bot);
  }
}
