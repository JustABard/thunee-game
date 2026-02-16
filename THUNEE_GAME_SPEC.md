# Thunee Card Game - Flutter App Specification

You are a senior Flutter engineer and game-logic designer. Build a complete Thunee card game app in Flutter with clean architecture and a strict rules engine. The app must support 4 players in fixed partnerships (North/South vs East/West), 6 tricks per round, trump calling, Thunee/Royals variants, Jodi, Double, Kunuck/Khanaak, full scoring to balls, and configurable house rules.

## HARD REQUIREMENTS

### 1) Tech
- Flutter (latest stable), null-safety, Dart 3.
- State management: Riverpod (preferred) or BLoC. Keep game rules in a pure Dart package/module independent of UI.
- Deterministic RNG with seed for shuffling (for replays/tests).
- Animations: smooth card dealing and trick-taking animations (basic is fine, but clean).
- Write unit tests for: dealing, trick winner logic, scoring, and each call type success/failure.

### 2) Game Modes
- Local offline mode: 1 human vs 3 bots OR 2 humans + 2 bots on one device (pass-and-play).
- Optional multiplayer abstraction: design interfaces so it can later plug into online play (but you can implement only offline if needed).
- Bot AI: start with a rule-based bot that follows suit, cuts when beneficial, and understands basic "don't partner-catch" behavior during Thunee/Royals.

### 3) Core Thunee Rules (traditional baseline)
- Use a 24-card play deck: ranks per suit: J, 9, A, 10, K, Q.
- Normal ranking: J > 9 > A > 10 > K > Q.
- Card points: J=30, 9=20, A=11, 10=10, K=3, Q=2.
- 4 players, partnerships opposite, counter-clockwise play.
- Round: 6 tricks, each player has 6 cards after dealing.
- Last trick bonus: +10 points to the team that wins the last trick.
- "Counting team" must reach >= 105 points after adjustments to win the round; else trump-making team wins the round.
- Calling/bidding: after 4 cards each, bidding increments of 10 (10,20,30,...). Highest call becomes trump-making side, and called points are treated as compensation added to the counting side when evaluating the round outcome.

### 4) Trick Play
- Must follow suit if possible.
- If void in suit led, player may play any card including trump.
- Highest of suit led wins unless trump is played, then highest trump wins.
- Winner of trick leads next trick.
- Include an optional strict "undercutting restriction" toggle (off by default): if a player plays trump after someone already cut, they may be required to overtrump unless they are out of non-trumps (implement as a configurable rule).

### 5) Special Calls (must be implemented)

#### A) THUNEE (enabled always)
- Can be called after all players have 6 cards and before first card is played.
- Thunee caller must win all 6 tricks; their partner must win 0 tricks.
- Thunee overrides other calls (Jodi ignored once Thunee starts).
- Trump is determined by suit of the first card led by the Thunee caller.
- Scoring (configurable defaults):
  - Success: caller team +4 balls
  - Fail (caught by opponent): opponents +4 balls
  - Partner catch (partner wins any trick): opponents +8 balls
- Enforce "hold game" flow: if any player presses a "Hold/Consider Call" button, prevent the opening lead until all eligible calls resolved.

#### B) ROYALS (HOUSE OPTION)
- Toggle: enableRoyals (default true as per user request).
- Royals call is similar to Thunee, but ranking reverses to: Q > K > 10 > A > 9 > J.
- Caller must win all 6 tricks; partner must win 0 tricks.
- Trump is suit of first card led by caller.
- Same ball scoring behavior as Thunee unless overridden in settings.

#### C) BLIND THUNEE (HOUSE OPTION)
- Toggle: enableBlindThunee (default true).
- Called before the last 2 cards are viewed by the caller:
  - After the first 4 cards each are dealt, caller chooses to "Blind Thunee".
  - Dealer deals remaining 2 cards each. Everyone may see theirs normally, but the blind caller cannot look at their last 2 until they have played and won their first 4 tricks using the first 4 cards.
  - Then they reveal last 2 cards and must win remaining 2 tricks.
- Ball scoring defaults configurable in settings (common values 6 or 8). Provide a settings field:
  - blindThuneeSuccessBalls (default 8)
  - blindThuneeFailBalls (default 8)
  - blindThuneePartnerCatchBalls (default 8) OR allow separate config.

#### D) BLIND ROYALS (HOUSE OPTION)
- Toggle: enableBlindRoyals (default true).
- Same as Blind Thunee, but with Royals ranking.

#### E) JODI / JODHI (bonus)
- Implement combinations and points:
  - K+Q same suit: 20, or 40 if trumps
  - J+Q+K same suit: 30, or 50 if trumps
- Jodi can only be called by player holding the cards, and only if still in their hand at call time.
- Default rule window: can be called right after team wins trick #1 or #3; must be called before the trick timing window closes (implement a clear UX: a "Call Jodi" button appears when eligible and disappears after the allowed window).
- Include toggle: enableFirstThirdOnlyJodiCalls (default true per user request) that strictly enforces the "only on 1st or 3rd trick" rule.

#### F) DOUBLE (last trick call)
- Called on the last trick when the caller believes their side has taken all tricks and will take the last.
- Defaults:
  - Success: +2 balls to caller team
  - Fail: +4 balls to opponents
- Block/penalize "cornerhouse double" if desired via a toggle, but default to allowing.

#### G) KUNUCK / KANAK / KHANAAK (HOUSE OPTION)
- Toggle: enableKunuck (default true).
- Callable only on the last trick by the player claiming it.
- Implement as a high-risk scoring call with defaults:
  - Success: +3 balls to caller team; also set matchTargetBalls = 13 for this match (instead of 12).
  - Fail: opponents +4 balls
- Provide a configuration field for the exact Kunuck evaluation rule (since communities differ):
  - Option 1 (default): Evaluate per "jodi + last trick bonus vs opponents points" style.
  - Option 2: Simple toggleable rule: "Kunuck succeeds if opponents end the round below a configured threshold".
- Build the engine so the rule can be swapped without rewriting the game.

### 6) USER REQUESTED HOUSE RULE OPTIONS (must be included)

#### A) enableCallOverTeammates
- When false: Partners may not bid against each other in a two-man bidding war.
- When true: If a third player enters bidding, allow either partner (on their turn) to continue raising calls for their team (but never directly "outbid" partner on the same team unless the system requires a seat order; seat order still applies).

#### B) enableCallAndLoss
- If true: If a player/team "called to make trumps" (i.e., made a numeric call and became trump-makers) AND then loses the round outcome, the winning team receives exactly +2 balls (override/replace the normal ball awarding for that round).
- Clarify UI: show "Call & Loss Applied" in the round summary when triggered.

#### C) enableRoyals, enableKunuck, enableBlindThunee, enableBlindRoyals, enableFirstThirdOnlyJodiCalls
- Provide all in a Settings screen with explanations.

### 7) SCORING TO BALLS (match progression)
- Keep a match score: teamA_balls, teamB_balls.
- Default target: 12 balls to win.
- If Kunuck succeeds and the rule says it becomes a 13-ball match, set target to 13 for that match.
- Round summary screen: show
  - which side was trump-makers / counting
  - total card points per team
  - all adjustments (calls to make trump, Jodi, last trick, penalties)
  - the final ">=105?" check
  - balls awarded and why

### 8) UI/UX
- Screens:
  - Home (Play / Settings / Rules)
  - Mode select (Bots / Pass-and-play)
  - Table view (4 seats, trick area center, trump indicator, current leader indicator)
  - Call phase UI (bidding ladder in 10s, show current call, allow pass)
  - Special call buttons when eligible (Thunee, Royals, Blind Thunee, Blind Royals, Jodi, Double, Kunuck)
  - Round summary and match summary
- Card visibility:
  - In pass-and-play: hide other hands; require handover tap + "Hide hand" transition.
  - For bots: show only human hand.

### 9) CODE STRUCTURE (must follow)
```
/lib
  /ui (screens, widgets)
  /state (Riverpod/BLoC controllers)
  /domain
    models: Card, Suit, Rank, Trick, Player, Team, RoundState, MatchState, CallType
    rules engine: TrickResolver, ScoringEngine, CallValidator, TurnManager
    bot: BotPolicy
  /data (optional: persistence for settings + match history)
```
- Provide thorough inline comments and a clear README: how to run, how to test, how rules are configured.

### 10) DELIVERABLE
- Generate the full Flutter project code (key files at minimum) and ensure it runs.
- Provide unit tests and at least one integration-style "simulate a full round" test.
- Ensure all rule toggles work and are reflected in the rules engine.

**IMPORTANT: Do NOT simplify the rules away; implement them as described with configuration toggles.**
