import '../models/call_type.dart';
import '../models/card.dart';
import '../models/game_config.dart';
import '../models/match_state.dart';
import '../models/player.dart';
import '../models/round_state.dart';
import '../models/suit.dart';
import '../models/team.dart';
import '../models/trick.dart';
import '../rules/call_validator.dart';
import '../rules/card_ranker.dart';
import '../rules/deck_manager.dart';
import '../rules/scoring_engine.dart';
import '../rules/trick_resolver.dart';
import '../rules/turn_manager.dart';
import 'rng_service.dart';
import '../../utils/constants.dart';

/// Result of an action in the game
class GameActionResult {
  final bool success;
  final String? errorMessage;
  final RoundState? newState;
  final MatchState? newMatchState;

  const GameActionResult.success({this.newState, this.newMatchState})
      : success = true,
        errorMessage = null;

  const GameActionResult.error(this.errorMessage)
      : success = false,
        newState = null,
        newMatchState = null;
}

/// Orchestrates all game rules and manages complete match flow.
/// This is the main entry point for game logic.
class GameEngine {
  final GameConfig config;
  final DeckManager deckManager;
  final CallValidator callValidator;
  final TrickResolver trickResolver;
  final TurnManager turnManager;
  final ScoringEngine scoringEngine;

  GameEngine({
    required this.config,
    RngService? rngService,
  })  : deckManager = DeckManager(rngService ?? RngService.unseeded()),
        callValidator = CallValidator(config),
        trickResolver = TrickResolver(CardRanker()),
        turnManager = TurnManager(),
        scoringEngine = ScoringEngine(config);

  /// Creates a new match with the given players
  MatchState createNewMatch(List<Player> players) {
    if (players.length != TOTAL_PLAYERS) {
      throw ArgumentError('Must have exactly $TOTAL_PLAYERS players');
    }

    return MatchState.newMatch(config: config, players: players);
  }

  /// Starts a new round by dealing cards
  GameActionResult startNewRound(MatchState matchState, Seat dealer) {
    if (matchState.currentRound != null) {
      return const GameActionResult.error('Round already in progress');
    }

    // Deal 4 cards to each player; hold back 2 per player until bidding completes
    final split = deckManager.dealSplit();

    // Update players with their initial 4-card hands
    final updatedPlayers = matchState.players.asMap().entries.map((entry) {
      final index = entry.key;
      final player = entry.value;
      return player.copyWith(hand: split.initial[index]);
    }).toList();

    // Reset teams for new round
    final resetTeams = matchState.teams.map((t) => t.resetRound()).toList();

    // Create initial round state
    final roundState = RoundState.initial(
      players: updatedPlayers,
      teams: resetTeams,
      dealer: dealer,
    );

    // Transition to bidding phase, storing the held-back cards
    final biddingState = roundState.copyWith(
      phase: RoundPhase.bidding,
      remainingCards: split.remaining,
    );

    final newMatchState = matchState.startNewRound(biddingState);

    return GameActionResult.success(
      newState: biddingState,
      newMatchState: newMatchState,
    );
  }

  /// Makes a bid.
  /// [bidder] specifies which seat is bidding (first-come-first-serve).
  GameActionResult makeBid({
    required RoundState state,
    required int amount,
    required Seat bidder,
  }) {
    final bid = BidCall(caller: bidder, amount: amount);

    // Validate bid
    final validation = callValidator.validateBid(bid: bid, state: state);
    if (!validation.isValid) {
      return GameActionResult.error(validation.errorMessage);
    }

    // Update state — don't advance turn (FCFS bidding has no turn order)
    final newCallHistory = [...state.callHistory, bid];
    final newState = state.copyWith(
      callHistory: newCallHistory,
      highestBid: bid,
      passCount: 0, // Reset pass count
      trumpMakingTeam: bidder.teamNumber,
    );

    // Check if we should transition to choosing trump
    final finalState = _checkBiddingComplete(newState);

    return GameActionResult.success(newState: finalState);
  }

  /// Passes on bidding.
  /// [passer] specifies which seat is passing (first-come-first-serve).
  GameActionResult passBid({
    required RoundState state,
    required Seat passer,
  }) {
    final pass = PassCall(caller: passer);

    // Validate pass
    final validation = callValidator.validatePass(pass: pass, state: state);
    if (!validation.isValid) {
      return GameActionResult.error(validation.errorMessage);
    }

    // Update state — don't advance turn (FCFS bidding has no turn order)
    final newCallHistory = [...state.callHistory, pass];
    final newState = state.copyWith(
      callHistory: newCallHistory,
      passCount: state.passCount + 1,
    );

    // Check if we should transition to choosing trump
    final finalState = _checkBiddingComplete(newState);

    return GameActionResult.success(newState: finalState);
  }

  /// Checks if bidding is complete and transitions to choosingTrump if needed.
  /// The 2 held-back cards are NOT distributed yet — that happens after trump is chosen.
  ///
  /// If all 4 players pass with no bid, the person to the right of the dealer
  /// (dealer.next) auto-becomes trump-maker at 0. This does NOT trigger call-and-loss.
  RoundState _checkBiddingComplete(RoundState state) {
    if (turnManager.shouldTransitionPhase(state)) {
      final nextPhase = turnManager.getNextPhase(state);

      if (nextPhase == RoundPhase.choosingTrump) {
        if (state.highestBid != null) {
          // Normal case: bid winner picks trump
          final bidWinner = state.highestBid!.caller;
          return state.copyWith(
            phase: RoundPhase.choosingTrump,
            currentTurn: bidWinner,
          );
        } else {
          // All passed — person to the right of dealer auto-gets trump at 0
          final defaultTrumpMaker = state.dealer.next;
          return state.copyWith(
            phase: RoundPhase.choosingTrump,
            currentTurn: defaultTrumpMaker,
            trumpMakingTeam: defaultTrumpMaker.teamNumber,
          );
        }
      }
    }

    return state;
  }

  /// Bid winner selects trump by tapping one of their cards.
  /// The chosen card's suit becomes trump; the card stays in hand.
  /// After selection the held-back 2 cards are dealt and play begins.
  GameActionResult selectTrump({
    required RoundState state,
    required Card card,
  }) {
    if (state.phase != RoundPhase.choosingTrump) {
      return const GameActionResult.error('Can only select trump during trump selection phase');
    }

    // Trump maker: bid winner, or dealer.next if all passed
    final caller = state.highestBid?.caller ?? state.dealer.next;
    final trumpSuit = card.suit;

    // Distribute remaining 2 cards now that trump is known
    final stateWithCards = state
        .copyWith(trumpSuit: trumpSuit, trumpCard: card)
        .distributeRemainingCards();

    // Person to the RIGHT of the trump-setter leads first (next in anti-clockwise order)
    final leader = caller.next;
    final trick = Trick.empty(leader);

    return GameActionResult.success(
      newState: stateWithCards.copyWith(
        phase: RoundPhase.playing,
        currentTrick: trick,
        currentTurn: leader,
      ),
    );
  }

  /// Plays a card
  GameActionResult playCard({
    required RoundState state,
    required Card card,
  }) {
    if (state.phase != RoundPhase.playing) {
      return const GameActionResult.error('Can only play cards during playing phase');
    }

    final player = state.currentPlayer;
    final trick = state.currentTrick!;

    // Validate card play
    final validation = trickResolver.validateCardPlay(
      card: card,
      player: player,
      trick: trick,
    );

    if (!validation.isValid) {
      return GameActionResult.error(validation.errorMessage);
    }

    // Remove card from player's hand
    final newHand = player.hand.where((c) => c != card).toList();
    final updatedPlayer = player.copyWith(hand: newHand);

    // Add card to trick
    final updatedTrick = trick.playCard(player.seat, card);

    // Trump is set via selectTrump, or by first card led in Thunee/Royals
    final trumpSuit = state.trumpSuit ?? card.suit;

    // Update state with new trick, player, and trump (may be newly set)
    var newState = state.updatePlayer(updatedPlayer).copyWith(
      currentTrick: updatedTrick,
      trumpSuit: trumpSuit,
    );

    // Check if trick is complete
    if (updatedTrick.isComplete) {
      newState = _completeTrick(newState, updatedTrick, trumpSuit);
    } else {
      // Move to next player
      newState = newState.copyWith(
        currentTurn: turnManager.getNextTurn(newState),
      );
    }

    return GameActionResult.success(newState: newState);
  }

  /// Completes a trick and determines winner.
  /// The completed trick is kept as [currentTrick] so the UI can display all
  /// 4 cards. The notifier is responsible for starting the next trick after a delay.
  RoundState _completeTrick(RoundState state, Trick trick, Suit trumpSuit) {
    // Determine winner
    final winner = trickResolver.determineWinner(
      trick: trick,
      trumpSuit: trumpSuit,
      isRoyalsMode: state.isRoyalsMode,
    );

    final completedTrick = trick.withWinner(winner);

    // Update team that won the trick
    final winningTeam = state.teamFor(winner);
    final updatedTeam = winningTeam.addTrick(completedTrick.points);

    // Add to completed tricks
    final newCompletedTricks = [...state.completedTricks, completedTrick];

    var newState = state
        .updateTeam(updatedTeam)
        .copyWith(
          completedTricks: newCompletedTricks,
          currentTrick: completedTrick, // Keep visible — notifier handles next trick
        );

    // Check for Thunee/Royals immediate failure
    final activeCall = newState.activeThuneeCall;
    if (activeCall != null && winner != activeCall.caller) {
      // Caller didn't win — Thunee/Royals failed, end round immediately
      newState = newState.copyWith(phase: RoundPhase.scoring);
      return newState;
    }

    // Check if round is complete (all 6 tricks played)
    if (newState.allTricksComplete) {
      newState = newState.copyWith(phase: RoundPhase.scoring);
    }

    return newState;
  }

  /// Makes a special call (Thunee, Royals, Jodi, Double, Kunuck)
  GameActionResult makeSpecialCall({
    required RoundState state,
    required CallData call,
  }) {
    // Look up the player who is making the call (not necessarily currentTurn)
    final player = state.playerAt(call.caller);

    // Validate call
    final validation = callValidator.validateCall(
      call: call,
      state: state,
      player: player,
    );

    if (!validation.isValid) {
      return GameActionResult.error(validation.errorMessage);
    }

    // Add to call history
    final newCallHistory = [...state.callHistory, call];

    // Thunee/Royals: caller leads first, first card's suit becomes trump
    if (call.category == CallCategory.thunee ||
        call.category == CallCategory.royals) {
      // Must construct directly — copyWith can't clear trumpSuit (uses ??)
      final newState = RoundState(
        phase: RoundPhase.playing,
        players: state.players,
        teams: state.teams,
        completedTricks: const [],
        currentTrick: Trick.empty(call.caller),
        callHistory: newCallHistory,
        highestBid: state.highestBid,
        passCount: state.passCount,
        trumpSuit: null, // Cleared — set by first card led
        trumpMakingTeam: call.caller.teamNumber,
        currentTurn: call.caller,
        dealer: state.dealer,
      );
      return GameActionResult.success(newState: newState);
    }

    final newState = state.copyWith(callHistory: newCallHistory);
    return GameActionResult.success(newState: newState);
  }

  /// Scores the current round and updates match state
  GameActionResult scoreRound({
    required RoundState roundState,
    required MatchState matchState,
  }) {
    if (roundState.phase != RoundPhase.scoring) {
      return const GameActionResult.error('Round is not in scoring phase');
    }

    // Calculate score
    final breakdown = scoringEngine.calculateRoundScore(roundState);

    // Update match state with balls
    var newMatchState = matchState;
    newMatchState = newMatchState.addBallsToTeam(0, breakdown.team0BallsAwarded);
    newMatchState = newMatchState.addBallsToTeam(1, breakdown.team1BallsAwarded);

    // Complete the round
    newMatchState = newMatchState.completeCurrentRound();

    return GameActionResult.success(
      newState: roundState,
      newMatchState: newMatchState,
    );
  }

  /// Gets legal cards that the current player can play
  List<Card> getLegalCards(RoundState state) {
    if (state.phase != RoundPhase.playing || state.currentTrick == null) {
      return [];
    }

    return trickResolver.getLegalCards(
      player: state.currentPlayer,
      trick: state.currentTrick!,
    );
  }

  /// Checks if a specific card is legal to play
  bool isCardLegal(RoundState state, Card card) {
    final legalCards = getLegalCards(state);
    return legalCards.contains(card);
  }
}
