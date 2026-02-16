// ===== THUNEE CARD GAME =====

const SUITS = ['Spades', 'Hearts', 'Diamonds', 'Clubs'];
const RANKS = ['J', '9', 'A', '10', 'K', 'Q'];
const SUIT_SYMBOLS = { Spades: '♠', Hearts: '♥', Diamonds: '♦', Clubs: '♣' };
const RANK_ORDER = { J: 6, 9: 5, A: 4, 10: 3, K: 2, Q: 1 };
const POINT_VALUES = { J: 3, 9: 2, A: 1, 10: 1, K: 0, Q: 0 };
const TOTAL_TRICKS = 6; // 24 cards / 4 players = 6 cards each = 6 tricks
const PLAYERS = ['south', 'west', 'north', 'east'];
const PLAYER_NAMES = { south: 'You', west: 'West', north: 'North', east: 'East' };
const TEAM_A = ['south', 'north']; // Human + partner
const TEAM_B = ['west', 'east'];

// Game state
let gameState = {
    settings: { targetBalls: 12, callAndLoss: false, jodiCalls: false },
    scores: { A: 0, B: 0 },
    round: 0,
    hands: {},
    trump: null,
    bid: { amount: 0, player: null, team: null },
    currentTrick: [],
    trickNumber: 0,
    leadPlayer: null,
    dealer: 0,
    tricksTaken: { A: 0, B: 0 },
    pointsTaken: { A: 0, B: 0 },
    blindRoyal: null,
    blindThunee: null,
    kunuck: null,
    jodiCalled: false,
    jodiTeam: null,
    phase: 'lobby' // lobby, dealing, bidding, trumpCall, playing, roundEnd
};

// ===== INITIALIZATION =====

document.getElementById('startGame').addEventListener('click', startGame);
document.getElementById('playAgain').addEventListener('click', () => {
    document.getElementById('gameOver').classList.add('hidden');
    document.getElementById('game').classList.add('hidden');
    document.getElementById('lobby').classList.remove('hidden');
});

function startGame() {
    gameState.settings.targetBalls = parseInt(document.getElementById('targetBalls').value) || 12;
    gameState.settings.callAndLoss = document.getElementById('callAndLoss').checked;
    gameState.settings.jodiCalls = document.getElementById('jodiCalls').checked;
    gameState.scores = { A: 0, B: 0 };
    gameState.round = 0;
    gameState.dealer = Math.floor(Math.random() * 4);

    document.getElementById('lobby').classList.add('hidden');
    document.getElementById('game').classList.remove('hidden');
    clearLog();
    updateScoreboard();
    startRound();
}

// ===== ROUND MANAGEMENT =====

function startRound() {
    gameState.round++;
    gameState.trump = null;
    gameState.bid = { amount: 0, player: null, team: null };
    gameState.currentTrick = [];
    gameState.trickNumber = 0;
    gameState.tricksTaken = { A: 0, B: 0 };
    gameState.pointsTaken = { A: 0, B: 0 };
    gameState.blindRoyal = null;
    gameState.blindThunee = null;
    gameState.kunuck = null;
    gameState.jodiCalled = false;
    gameState.jodiTeam = null;
    gameState.phase = 'dealing';

    document.getElementById('roundNum').textContent = gameState.round;
    document.getElementById('trickNum').textContent = '1';
    document.getElementById('trumpIndicator').classList.add('hidden');
    document.getElementById('bidInfo').classList.add('hidden');

    log(`--- Round ${gameState.round} ---`, true);
    log(`Dealer: ${PLAYER_NAMES[PLAYERS[gameState.dealer]]}`);

    dealCards();
    renderAllHands();

    // Ask human for blind calls before bidding
    askBlindCalls();
}

function dealCards() {
    const deck = [];
    for (const suit of SUITS) {
        for (const rank of RANKS) {
            deck.push({ suit, rank });
        }
    }
    shuffle(deck);

    gameState.hands = {};
    for (let i = 0; i < 4; i++) {
        const player = PLAYERS[i];
        gameState.hands[player] = deck.slice(i * 6, (i + 1) * 6);
        // Sort hand by suit then rank
        gameState.hands[player].sort((a, b) => {
            if (a.suit !== b.suit) return SUITS.indexOf(a.suit) - SUITS.indexOf(b.suit);
            return RANK_ORDER[b.rank] - RANK_ORDER[a.rank];
        });
    }
}

function shuffle(arr) {
    for (let i = arr.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [arr[i], arr[j]] = [arr[j], arr[i]];
    }
}

// ===== BLIND CALLS =====

function askBlindCalls() {
    showAction('Before looking at cards, do you want to make a blind call?', [
        { text: 'Blind Royal (4 balls)', class: 'btn-special', action: () => makeBlindCall('blindRoyal') },
        { text: 'Blind Thunee (2 balls)', class: 'btn-special', action: () => makeBlindCall('blindThunee') },
        { text: 'No Blind Call', class: 'btn-pass', action: () => startBidding() }
    ]);
}

function makeBlindCall(type) {
    const team = getTeam('south');
    if (type === 'blindRoyal') {
        gameState.blindRoyal = team;
        log('You called Blind Royal! (4 balls at stake)', true);
    } else {
        gameState.blindThunee = team;
        log('You called Blind Thunee! (2 balls at stake)', true);
    }
    startBidding();
}

// ===== BIDDING =====

function startBidding() {
    gameState.phase = 'bidding';
    const startPlayer = (gameState.dealer + 1) % 4;
    runBidding(startPlayer, 0, [false, false, false, false]);
}

function runBidding(currentIdx, highBid, passed) {
    const player = PLAYERS[currentIdx];

    // Count active bidders
    const activeBidders = passed.filter(p => !p).length;
    if (activeBidders <= 1 && highBid > 0) {
        // Find the winner
        for (let i = 0; i < 4; i++) {
            if (!passed[i] && gameState.bid.player === PLAYERS[i]) {
                finalizeBid();
                return;
            }
        }
    }

    // All passed with no bid
    if (passed.every(p => p)) {
        // Redeal
        log('All players passed. Redealing...');
        gameState.dealer = (gameState.dealer + 1) % 4;
        setTimeout(() => startRound(), 1000);
        return;
    }

    if (passed[currentIdx]) {
        runBidding((currentIdx + 1) % 4, highBid, passed);
        return;
    }

    if (player === 'south') {
        humanBid(currentIdx, highBid, passed);
    } else {
        aiBid(currentIdx, highBid, passed);
    }
}

function humanBid(currentIdx, highBid, passed) {
    const minBid = Math.max(15, highBid + 1);
    const buttons = [];

    // Can bid over teammate
    const canBid = true;
    if (canBid) {
        for (let b = minBid; b <= 28; b++) {
            buttons.push({
                text: `${b}`,
                class: 'btn-bid',
                action: () => {
                    gameState.bid = { amount: b, player: 'south', team: 'A' };
                    log(`You bid ${b}`);
                    passed[currentIdx] = false;
                    runBidding((currentIdx + 1) % 4, b, passed);
                }
            });
        }
    }

    buttons.push({
        text: 'Pass',
        class: 'btn-pass',
        action: () => {
            passed[currentIdx] = true;
            log('You passed');
            runBidding((currentIdx + 1) % 4, highBid, passed);
        }
    });

    showAction(`Bidding — Current high bid: ${highBid || 'None'}. Your bid?`, buttons);
}

function aiBid(currentIdx, highBid, passed) {
    const player = PLAYERS[currentIdx];
    const hand = gameState.hands[player];
    const strength = evaluateHand(hand);
    const minBid = Math.max(15, highBid + 1);

    setTimeout(() => {
        // Simple AI: bid based on hand strength
        if (strength >= minBid && strength <= 28 && Math.random() > 0.3) {
            const bid = Math.min(Math.max(minBid, Math.floor(strength)), 28);
            gameState.bid = { amount: bid, player, team: getTeam(player) };
            log(`${PLAYER_NAMES[player]} bids ${bid}`);
            runBidding((currentIdx + 1) % 4, bid, passed);
        } else {
            passed[currentIdx] = true;
            log(`${PLAYER_NAMES[player]} passes`);
            runBidding((currentIdx + 1) % 4, highBid, passed);
        }
    }, 500);
}

function evaluateHand(hand) {
    let score = 0;
    const suitCounts = {};
    for (const card of hand) {
        score += POINT_VALUES[card.rank];
        suitCounts[card.suit] = (suitCounts[card.suit] || 0) + 1;
        if (card.rank === 'J') score += 4;
        if (card.rank === '9') score += 3;
    }
    // Bonus for long suits
    for (const count of Object.values(suitCounts)) {
        if (count >= 3) score += count;
    }
    return score;
}

function finalizeBid() {
    const { player, amount, team } = gameState.bid;
    log(`${PLAYER_NAMES[player]} wins the bid at ${amount}`, true);
    document.getElementById('bidInfo').classList.remove('hidden');
    document.getElementById('bidAmount').textContent = amount;
    document.getElementById('bidder').textContent = PLAYER_NAMES[player];

    if (player === 'south') {
        askTrumpCall();
    } else {
        aiCallTrump(player);
    }
}

// ===== TRUMP CALLING =====

function askTrumpCall() {
    const buttons = SUITS.map(suit => ({
        text: `${SUIT_SYMBOLS[suit]} ${suit}`,
        class: 'btn-trump',
        action: () => setTrump(suit, 'south')
    }));
    showAction('You won the bid! Choose trump suit:', buttons);
}

function aiCallTrump(player) {
    const hand = gameState.hands[player];
    const suitStrength = {};
    for (const suit of SUITS) {
        suitStrength[suit] = 0;
        for (const card of hand) {
            if (card.suit === suit) {
                suitStrength[suit] += RANK_ORDER[card.rank] + POINT_VALUES[card.rank];
            }
        }
    }
    const bestSuit = SUITS.reduce((a, b) => suitStrength[a] >= suitStrength[b] ? a : b);
    setTimeout(() => setTrump(bestSuit, player), 500);
}

function setTrump(suit, caller) {
    gameState.trump = suit;
    gameState.phase = 'playing';
    log(`${PLAYER_NAMES[caller]} calls ${SUIT_SYMBOLS[suit]} ${suit} as trump!`, true);

    document.getElementById('trumpIndicator').classList.remove('hidden');
    document.getElementById('trumpSuit').textContent = `${SUIT_SYMBOLS[suit]} ${suit}`;
    document.getElementById('trumpSuit').className = suit === 'Hearts' || suit === 'Diamonds' ? 'suit-hearts' : 'suit-spades';

    hideAction();

    // Ask for kunuck
    askKunuck();
}

// ===== KUNUCK =====

function askKunuck() {
    if (gameState.kunuck) {
        startTrickPlay();
        return;
    }

    showAction('Do you want to Kunuck (knock) to double the stakes?', [
        { text: 'Kunuck! (Double stakes)', class: 'btn-special', action: () => {
            gameState.kunuck = 'A';
            log('You kunucked! Stakes doubled!', true);
            hideAction();
            // AI might counter-kunuck (simplified: skip)
            startTrickPlay();
        }},
        { text: 'No', class: 'btn-pass', action: () => {
            hideAction();
            startTrickPlay();
        }}
    ]);
}

// ===== TRICK PLAY =====

function startTrickPlay() {
    gameState.trickNumber = 1;
    // Lead player is the bid winner
    gameState.leadPlayer = PLAYERS.indexOf(gameState.bid.player);
    playTrick();
}

function playTrick() {
    gameState.currentTrick = [];
    clearTrickArea();
    document.getElementById('trickNum').textContent = gameState.trickNumber;
    renderAllHands();

    playNextCard(gameState.leadPlayer);
}

function playNextCard(currentIdx) {
    if (gameState.currentTrick.length === 4) {
        resolveTrick();
        return;
    }

    const player = PLAYERS[currentIdx];

    if (player === 'south') {
        humanPlayCard(currentIdx);
    } else {
        aiPlayCard(currentIdx);
    }
}

function humanPlayCard(currentIdx) {
    const hand = gameState.hands.south;
    const leadSuit = gameState.currentTrick.length > 0 ? gameState.currentTrick[0].card.suit : null;
    const playable = getPlayableCards(hand, leadSuit);

    // Check for Jodi call opportunity
    if (gameState.settings.jodiCalls && !gameState.jodiCalled && gameState.trickNumber <= 3) {
        const hasJodi = checkJodi('south');
        if (hasJodi) {
            showAction('You have Jodi (J+9 of trump)! Call it for bonus?', [
                { text: 'Call Jodi!', class: 'btn-special', action: () => {
                    gameState.jodiCalled = true;
                    gameState.jodiTeam = 'A';
                    log('You called Jodi! (J+9 of trump)', true);
                    hideAction();
                    enableCardSelection(hand, playable, currentIdx);
                }},
                { text: 'Not now', class: 'btn-pass', action: () => {
                    hideAction();
                    enableCardSelection(hand, playable, currentIdx);
                }}
            ]);
            return;
        }
    }

    enableCardSelection(hand, playable, currentIdx);
}

function enableCardSelection(hand, playable, currentIdx) {
    hideAction();
    renderSouthHand(hand, playable, (cardIdx) => {
        const card = hand[cardIdx];
        hand.splice(cardIdx, 1);
        placeCardOnTrick('south', card);
        gameState.currentTrick.push({ player: 'south', card });
        log(`You played ${card.rank}${SUIT_SYMBOLS[card.suit]}`);
        renderAllHands();
        setTimeout(() => playNextCard((currentIdx + 1) % 4), 300);
    });
}

function aiPlayCard(currentIdx) {
    const player = PLAYERS[currentIdx];
    const hand = gameState.hands[player];
    const leadSuit = gameState.currentTrick.length > 0 ? gameState.currentTrick[0].card.suit : null;
    const playable = getPlayableCards(hand, leadSuit);

    // AI Jodi call
    if (gameState.settings.jodiCalls && !gameState.jodiCalled && gameState.trickNumber <= 3) {
        if (checkJodi(player)) {
            gameState.jodiCalled = true;
            gameState.jodiTeam = getTeam(player);
            log(`${PLAYER_NAMES[player]} calls Jodi!`, true);
        }
    }

    setTimeout(() => {
        const cardIdx = aiChooseCard(player, hand, playable, leadSuit);
        const card = hand[cardIdx];
        hand.splice(cardIdx, 1);
        placeCardOnTrick(player, card);
        gameState.currentTrick.push({ player, card });
        log(`${PLAYER_NAMES[player]} played ${card.rank}${SUIT_SYMBOLS[card.suit]}`);
        renderAllHands();
        setTimeout(() => playNextCard((currentIdx + 1) % 4), 300);
    }, 600);
}

function aiChooseCard(player, hand, playable, leadSuit) {
    // Simple AI strategy
    const playableCards = playable.map(i => ({ idx: i, card: hand[i] }));

    if (!leadSuit) {
        // Leading: play highest trump or highest card
        const trumpCards = playableCards.filter(c => c.card.suit === gameState.trump);
        if (trumpCards.length > 0 && Math.random() > 0.5) {
            return trumpCards[0].idx;
        }
        // Play highest non-trump
        const nonTrump = playableCards.filter(c => c.card.suit !== gameState.trump);
        if (nonTrump.length > 0) return nonTrump[0].idx;
        return playableCards[0].idx;
    }

    // Following suit
    const suitCards = playableCards.filter(c => c.card.suit === leadSuit);
    if (suitCards.length > 0) {
        // Try to win with highest
        const currentWinner = getTrickWinner();
        const winnerCard = currentWinner ? currentWinner.card : null;
        if (winnerCard && getTeam(currentWinner.player) === getTeam(player)) {
            // Partner is winning, play low
            return suitCards[suitCards.length - 1].idx;
        }
        return suitCards[0].idx; // Play highest
    }

    // Can't follow suit - trump if possible
    const trumpCards = playableCards.filter(c => c.card.suit === gameState.trump);
    if (trumpCards.length > 0) {
        return trumpCards[trumpCards.length - 1].idx; // Play lowest trump
    }

    // Discard lowest
    return playableCards[playableCards.length - 1].idx;
}

function getPlayableCards(hand, leadSuit) {
    if (!leadSuit) return hand.map((_, i) => i);

    const suitCards = hand.map((c, i) => ({ card: c, idx: i })).filter(c => c.card.suit === leadSuit);
    if (suitCards.length > 0) return suitCards.map(c => c.idx);

    return hand.map((_, i) => i); // Can play anything
}

function getTrickWinner() {
    if (gameState.currentTrick.length === 0) return null;

    const leadSuit = gameState.currentTrick[0].card.suit;
    let winner = gameState.currentTrick[0];

    for (let i = 1; i < gameState.currentTrick.length; i++) {
        const entry = gameState.currentTrick[i];
        if (beats(entry.card, winner.card, leadSuit)) {
            winner = entry;
        }
    }
    return winner;
}

function beats(card, current, leadSuit) {
    const trump = gameState.trump;
    const cardIsTrump = card.suit === trump;
    const currentIsTrump = current.suit === trump;

    if (cardIsTrump && !currentIsTrump) return true;
    if (!cardIsTrump && currentIsTrump) return false;
    if (cardIsTrump && currentIsTrump) return RANK_ORDER[card.rank] > RANK_ORDER[current.rank];

    // Neither is trump
    if (card.suit === leadSuit && current.suit !== leadSuit) return true;
    if (card.suit !== leadSuit && current.suit === leadSuit) return false;
    if (card.suit === leadSuit && current.suit === leadSuit) {
        return RANK_ORDER[card.rank] > RANK_ORDER[current.rank];
    }
    return false;
}

function resolveTrick() {
    const winner = getTrickWinner();
    const winnerTeam = getTeam(winner.player);
    gameState.tricksTaken[winnerTeam]++;

    let trickPoints = 0;
    for (const entry of gameState.currentTrick) {
        trickPoints += POINT_VALUES[entry.card.rank];
    }
    gameState.pointsTaken[winnerTeam] += trickPoints;

    log(`${PLAYER_NAMES[winner.player]} wins trick ${gameState.trickNumber} (+${trickPoints} pts)`, true);
    log(`Points — A: ${gameState.pointsTaken.A}, B: ${gameState.pointsTaken.B}`);

    gameState.leadPlayer = PLAYERS.indexOf(winner.player);

    setTimeout(() => {
        gameState.trickNumber++;
        if (gameState.trickNumber > TOTAL_TRICKS) {
            // Check Jodi forfeiture
            if (gameState.settings.jodiCalls && !gameState.jodiCalled) {
                // Check if anyone had Jodi but didn't call it
                for (const player of PLAYERS) {
                    // Already played all cards, so we can't check. Jodi is forfeited.
                }
            }
            endRound();
        } else {
            playTrick();
        }
    }, 1200);
}

// ===== ROUND END =====

function endRound() {
    gameState.phase = 'roundEnd';
    const bidTeam = gameState.bid.team;
    const bidAmount = gameState.bid.amount;
    const bidPoints = gameState.pointsTaken[bidTeam];
    const otherTeam = bidTeam === 'A' ? 'B' : 'A';

    let ballsWon = { A: 0, B: 0 };
    const isRoyal = gameState.tricksTaken[bidTeam] === TOTAL_TRICKS;
    const opponentRoyal = gameState.tricksTaken[otherTeam] === TOTAL_TRICKS;

    if (bidPoints >= bidAmount) {
        // Bid team made it
        if (isRoyal) {
            if (gameState.blindRoyal === bidTeam) {
                ballsWon[bidTeam] = 4;
                log(`${bidTeam === 'A' ? 'Team A' : 'Team B'} gets a BLIND ROYAL! +4 balls!`, true);
            } else {
                ballsWon[bidTeam] = 3;
                log(`${bidTeam === 'A' ? 'Team A' : 'Team B'} gets a ROYAL! +3 balls!`, true);
            }
        } else {
            ballsWon[bidTeam] = 1;
            log(`${bidTeam === 'A' ? 'Team A' : 'Team B'} made their bid! +1 ball`, true);
        }
    } else {
        // Bid team failed
        if (opponentRoyal) {
            ballsWon[otherTeam] = 3;
            log(`${otherTeam === 'A' ? 'Team A' : 'Team B'} gets a ROYAL! +3 balls!`, true);
        } else if (gameState.settings.callAndLoss) {
            ballsWon[otherTeam] = 2;
            log(`Call and Loss! ${otherTeam === 'A' ? 'Team A' : 'Team B'} gets +2 balls!`, true);
        } else {
            ballsWon[otherTeam] = 1;
            log(`${bidTeam === 'A' ? 'Team A' : 'Team B'} failed their bid. ${otherTeam === 'A' ? 'Team A' : 'Team B'} +1 ball`, true);
        }
    }

    // Blind Thunee modifier
    if (gameState.blindThunee) {
        const btTeam = gameState.blindThunee;
        if (ballsWon[btTeam] > 0) {
            ballsWon[btTeam] = Math.max(ballsWon[btTeam], 2);
            log(`Blind Thunee bonus applied!`, true);
        }
    }

    // Kunuck modifier (doubles)
    if (gameState.kunuck) {
        for (const t of ['A', 'B']) {
            if (ballsWon[t] > 0) {
                ballsWon[t] *= 2;
            }
        }
        if (gameState.kunuck) log(`Kunuck doubled the stakes!`, true);
    }

    // Jodi bonus
    if (gameState.jodiCalled && gameState.jodiTeam) {
        ballsWon[gameState.jodiTeam] = (ballsWon[gameState.jodiTeam] || 0) + 1;
        log(`Jodi bonus: +1 ball for ${gameState.jodiTeam === 'A' ? 'Team A' : 'Team B'}`, true);
    }

    gameState.scores.A += ballsWon.A;
    gameState.scores.B += ballsWon.B;
    updateScoreboard();

    log(`Score — Team A: ${gameState.scores.A}, Team B: ${gameState.scores.B}`, true);

    // Check for game over
    if (gameState.scores.A >= gameState.settings.targetBalls) {
        showGameOver('Team A Wins!', 'You and North win the game!');
        return;
    }
    if (gameState.scores.B >= gameState.settings.targetBalls) {
        showGameOver('Team B Wins!', 'West and East win the game!');
        return;
    }

    // Next round
    gameState.dealer = (gameState.dealer + 1) % 4;
    setTimeout(() => {
        clearTrickArea();
        startRound();
    }, 2000);
}

function showGameOver(title, message) {
    document.getElementById('gameOverTitle').textContent = title;
    document.getElementById('gameOverMessage').textContent = message;
    document.getElementById('finalScores').textContent =
        `Team A: ${gameState.scores.A} balls | Team B: ${gameState.scores.B} balls`;
    document.getElementById('gameOver').classList.remove('hidden');
}

// ===== JODI CHECK =====

function checkJodi(player) {
    const hand = gameState.hands[player];
    if (!gameState.trump) return false;
    const hasJ = hand.some(c => c.rank === 'J' && c.suit === gameState.trump);
    const has9 = hand.some(c => c.rank === '9' && c.suit === gameState.trump);
    return hasJ && has9;
}

// ===== RENDERING =====

function renderAllHands() {
    renderAIHand('north', 'northHand');
    renderAIHand('west', 'westHand');
    renderAIHand('east', 'eastHand');
    renderSouthHand(gameState.hands.south, null, null);
}

function renderAIHand(player, elementId) {
    const el = document.getElementById(elementId);
    const count = gameState.hands[player] ? gameState.hands[player].length : 0;
    el.innerHTML = '';
    for (let i = 0; i < count; i++) {
        const back = document.createElement('div');
        back.className = 'card-back';
        el.appendChild(back);
    }
}

function renderSouthHand(hand, playable, onSelect) {
    const el = document.getElementById('southHand');
    el.innerHTML = '';

    if (!hand) return;

    hand.forEach((card, idx) => {
        const cardEl = createCardElement(card);
        const isPlayable = playable ? playable.includes(idx) : false;

        if (playable && !isPlayable) {
            cardEl.classList.add('disabled');
        }

        if (onSelect && isPlayable) {
            cardEl.addEventListener('click', () => onSelect(idx));
        } else if (!onSelect) {
            cardEl.style.cursor = 'default';
        }

        el.appendChild(cardEl);
    });
}

function createCardElement(card) {
    const el = document.createElement('div');
    const isRed = card.suit === 'Hearts' || card.suit === 'Diamonds';
    el.className = `card ${isRed ? 'red' : 'black'} card-animate`;

    const isTrump = card.suit === gameState.trump;
    if (isTrump) {
        el.style.borderColor = '#ffd700';
        el.style.boxShadow = '0 0 6px rgba(255,215,0,0.3)';
    }

    el.innerHTML = `
        <span class="card-rank">${card.rank}</span>
        <span class="card-suit">${SUIT_SYMBOLS[card.suit]}</span>
    `;
    return el;
}

function placeCardOnTrick(player, card) {
    const slotId = 'trick' + player.charAt(0).toUpperCase() + player.slice(1);
    const slot = document.getElementById(slotId);
    slot.innerHTML = '';
    const cardEl = createCardElement(card);
    cardEl.style.cursor = 'default';
    slot.appendChild(cardEl);
}

function clearTrickArea() {
    ['trickNorth', 'trickSouth', 'trickWest', 'trickEast'].forEach(id => {
        document.getElementById(id).innerHTML = '';
    });
}

// ===== UI HELPERS =====

function showAction(message, buttons) {
    const panel = document.getElementById('actionPanel');
    const msgEl = document.getElementById('actionMessage');
    const btnEl = document.getElementById('actionButtons');

    msgEl.textContent = message;
    btnEl.innerHTML = '';

    buttons.forEach(btn => {
        const b = document.createElement('button');
        b.textContent = btn.text;
        b.className = btn.class || '';
        b.addEventListener('click', () => {
            hideAction();
            btn.action();
        });
        btnEl.appendChild(b);
    });

    panel.classList.remove('hidden');
}

function hideAction() {
    document.getElementById('actionPanel').classList.add('hidden');
}

function updateScoreboard() {
    document.getElementById('scoreA').textContent = gameState.scores.A;
    document.getElementById('scoreB').textContent = gameState.scores.B;
}

function log(message, important = false) {
    const content = document.getElementById('logContent');
    const entry = document.createElement('div');
    entry.className = `log-entry${important ? ' important' : ''}`;
    entry.textContent = message;
    content.appendChild(entry);
    content.scrollTop = content.scrollHeight;
}

function clearLog() {
    document.getElementById('logContent').innerHTML = '';
}

// ===== UTILITY =====

function getTeam(player) {
    return TEAM_A.includes(player) ? 'A' : 'B';
}
