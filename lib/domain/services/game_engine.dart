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

    // Deal cards
    final hands = deckManager.dealNewGame();

    // Update players with their hands
    final updatedPlayers = matchState.players.asMap().entries.map((entry) {
      final index = entry.key;
      final player = entry.value;
      return player.copyWith(hand: hands[index]);
    }).toList();

    // Reset teams for new round
    final resetTeams = matchState.teams.map((t) => t.resetRound()).toList();

    // Create initial round state
    final roundState = RoundState.initial(
      players: updatedPlayers,
      teams: resetTeams,
      dealer: dealer,
    );

    // Transition to bidding phase
    final biddingState = roundState.copyWith(phase: RoundPhase.bidding);

    final newMatchState = matchState.startNewRound(biddingState);

    return GameActionResult.success(
      newState: biddingState,
      newMatchState: newMatchState,
    );
  }

  /// Makes a bid
  GameActionResult makeBid({
    required RoundState state,
    required int amount,
  }) {
    final bidder = state.currentPlayer;
    final bid = BidCall(caller: bidder.seat, amount: amount);

    // Validate bid
    final validation = callValidator.validateBid(bid: bid, state: state);
    if (!validation.isValid) {
      return GameActionResult.error(validation.errorMessage);
    }

    // Update state
    final newCallHistory = [...state.callHistory, bid];
    final newState = state.copyWith(
      callHistory: newCallHistory,
      highestBid: bid,
      passCount: 0, // Reset pass count
      trumpMakingTeam: bidder.seat.teamNumber,
      currentTurn: turnManager.getNextTurn(state),
    );

    // Check if we should transition to playing phase
    final finalState = _checkBiddingComplete(newState);

    return GameActionResult.success(newState: finalState);
  }

  /// Passes on bidding
  GameActionResult passBid(RoundState state) {
    final passer = state.currentPlayer;
    final pass = PassCall(caller: passer.seat);

    // Validate pass
    final validation = callValidator.validatePass(pass: pass, state: state);
    if (!validation.isValid) {
      return GameActionResult.error(validation.errorMessage);
    }

    // Update state
    final newCallHistory = [...state.callHistory, pass];
    final newState = state.copyWith(
      callHistory: newCallHistory,
      passCount: state.passCount + 1,
      currentTurn: turnManager.getNextTurn(state),
    );

    // Check if we should transition to playing phase
    final finalState = _checkBiddingComplete(newState);

    return GameActionResult.success(newState: finalState);
  }

  /// Checks if bidding is complete and transitions to playing if needed
  RoundState _checkBiddingComplete(RoundState state) {
    if (turnManager.shouldTransitionPhase(state)) {
      final nextPhase = turnManager.getNextPhase(state);

      if (nextPhase == RoundPhase.playing) {
        // Determine first trick leader
        final leader = turnManager.getFirstTrickLeader(state);
        final trick = Trick.empty(leader);

        // Set trump suit if we have a bid
        Suit? trumpSuit = state.trumpSuit;
        if (state.highestBid != null && trumpSuit == null) {
          // Trump will be determined by first card led (or from special call)
          // For now, leave it null until first card is played
        }

        return state.copyWith(
          phase: nextPhase,
          currentTrick: trick,
          currentTurn: leader,
          trumpSuit: trumpSuit,
        );
      }
    }

    return state;
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

    // Determine trump suit from first card if needed
    Suit? trumpSuit = state.trumpSuit;
    if (trumpSuit == null && trick.isEmpty) {
      // First card of round determines trump
      trumpSuit = card.suit;
    }

    // Update state with new trick and player
    var newState = state.updatePlayer(updatedPlayer).copyWith(
      currentTrick: updatedTrick,
      trumpSuit: trumpSuit,
    );

    // Check if trick is complete
    if (updatedTrick.isComplete) {
      newState = _completeTrick(newState, updatedTrick, trumpSuit!);
    } else {
      // Move to next player
      newState = newState.copyWith(
        currentTurn: turnManager.getNextTurn(newState),
      );
    }

    return GameActionResult.success(newState: newState);
  }

  /// Completes a trick and determines winner
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
        .copyWith(completedTricks: newCompletedTricks);

    // Check if round is complete
    if (newState.allTricksComplete) {
      newState = newState.copyWith(
        phase: RoundPhase.scoring,
        currentTrick: null,
      );
    } else {
      // Start new trick with winner leading
      newState = newState.copyWith(
        currentTrick: Trick.empty(winner),
        currentTurn: winner,
      );
    }

    return newState;
  }

  /// Makes a special call (Thunee, Royals, Jodi, Double, Kunuck)
  GameActionResult makeSpecialCall({
    required RoundState state,
    required CallData call,
  }) {
    final player = state.currentPlayer;

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
