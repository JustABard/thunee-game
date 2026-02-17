/// Game constants for Thunee

// Card point values
const int JACK_POINTS = 30;
const int NINE_POINTS = 20;
const int ACE_POINTS = 11;
const int TEN_POINTS = 10;
const int KING_POINTS = 3;
const int QUEEN_POINTS = 2;

// Total points available in a round
const int TOTAL_POINTS_PER_ROUND = 314; // Sum of all card points (304) + last trick bonus (10)
const int TOTAL_CARD_POINTS = 304; // (J=30, 9=20, A=11, 10=10, K=3, Q=2) × 4 suits = 76 × 4
const int POINTS_PER_SUIT = 76; // J=30, 9=20, A=11, 10=10, K=3, Q=2
const int LAST_TRICK_BONUS = 10;

// Deck configuration
const int CARDS_PER_SUIT = 6;
const int TOTAL_SUITS = 4;
const int TOTAL_CARDS = 24; // 6 cards × 4 suits
const int CARDS_PER_PLAYER = 6;
const int INITIAL_DEAL_CARDS = 4; // Cards dealt before bidding
const int REMAINING_DEAL_CARDS = 2; // Cards dealt after bidding
const int TOTAL_PLAYERS = 4;
const int TRICKS_PER_ROUND = 6;

// Bidding
const int MIN_BID = 10;
const int BID_INCREMENT = 10;
const int MAX_BID = 150; // Theoretical max

// Match scoring
const int DEFAULT_MATCH_TARGET = 12; // Balls needed to win
const int KUNUCK_MATCH_TARGET = 13; // Target when Kunuck is played
const int WINNING_THRESHOLD = 105; // Points needed to count for the round

// Special call ball values
const int THUNEE_SUCCESS_BALLS = 4;
const int THUNEE_FAIL_BALLS = -4;
const int THUNEE_PARTNER_CATCH_BALLS = 8; // Opponents get +8

const int ROYALS_SUCCESS_BALLS = 4;
const int ROYALS_FAIL_BALLS = -4;
const int ROYALS_PARTNER_CATCH_BALLS = 8; // Opponents get +8

const int DEFAULT_BLIND_THUNEE_SUCCESS_BALLS = 8;
const int DEFAULT_BLIND_ROYALS_SUCCESS_BALLS = 8;
const int BLIND_FAIL_BALLS = -8;

const int DOUBLE_SUCCESS_BALLS = 2;
const int DOUBLE_FAIL_BALLS = -4;

const int KUNUCK_SUCCESS_BALLS = 3;
const int KUNUCK_FAIL_BALLS = -4;

// Jodi scoring (these are points, not balls)
const int JODI_KING_QUEEN = 20;
const int JODI_KING_QUEEN_TRUMP = 40;
const int JODI_JACK_QUEEN_KING = 30;
const int JODI_JACK_QUEEN_KING_TRUMP = 50;

// Call & Loss rule
const int CALL_AND_LOSS_BALLS = 2; // Balls awarded to opponents if trump-making team loses

// Timing windows for calls
const int BLIND_CALL_AFTER_CARDS = 4; // Blind calls can only happen after 4 cards dealt
const int THUNEE_CALL_AFTER_CARDS = 6; // Thunee calls after all 6 cards dealt

// Animation durations (milliseconds)
const int DEAL_ANIMATION_DURATION = 500;
const int PLAY_ANIMATION_DURATION = 300;
const int COLLECT_ANIMATION_DURATION = 500;
const int FLIP_ANIMATION_DURATION = 400;

// UI delays
const int BOT_TURN_DELAY = 1000; // Delay before bot plays (ms)
const int TRICK_COMPLETE_DELAY = 1500; // Delay before collecting trick (ms)
