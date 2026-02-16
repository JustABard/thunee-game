# 🃏 Thunee — South African Card Game

A web-based implementation of **Thunee**, a popular South African trick-taking card game played with 4 players in 2 teams.

## 🎮 How to Play

Open `index.html` in any modern web browser — no server or installation required.

You play as **South** (Team A) with an AI partner (**North**). You compete against **West** and **East** (Team B, both AI).

## 📜 Rules

### The Deck
- **24 cards**: Jack, 9, Ace, 10, King, Queen of each suit (♠ ♥ ♦ ♣)
- **Card ranking** (high to low): J → 9 → A → 10 → K → Q
- **Point values**: J=3, 9=2, A=1, 10=1, K=0, Q=0
- **Total points in deck**: 28

### Teams
- **Team A**: You (South) + North (AI partner)
- **Team B**: West (AI) + East (AI)
- Partners sit across from each other

### Dealing
Each player receives 6 cards (all 24 cards dealt). The dealer rotates each round.

### Bidding
1. Starting left of the dealer, players bid for the right to call trump
2. Minimum bid is **15**
3. Players can bid higher or pass
4. Players may outbid their own teammate (calling over)
5. The highest bidder wins and chooses the trump suit
6. If all players pass, cards are redealt

### Playing Tricks
1. The bid winner leads the first trick
2. Players must **follow suit** if possible
3. If you can't follow suit, you may play any card (including trump)
4. **Trump beats non-trump**; highest card of the led suit wins if no trump is played
5. The trick winner leads the next trick
6. **6 tricks** are played per round

### Scoring
- If the bidding team's points from tricks **≥ their bid**, they score **1 ball**
- If they fail, the opposing team scores **1 ball**
- First team to reach the **target balls** (default: 12) wins the game

## ✨ Special Features

### Royals
- A **Royal** occurs when one team wins **all 6 tricks** in a round
- Worth **3 balls** instead of 1
- **Blind Royal**: Called before seeing your cards — worth **4 balls**

### Kunuck (Knock)
- A player can **kunuck** (knock) to signal confidence
- **Doubles** the ball stakes for that round
- If the knocking team wins, they get 2× balls; if they lose, opponents get 2× balls

### Blind Thunee
- Called before looking at cards
- Worth **2 balls** minimum
- Can be combined with Blind Royal

### Jodi
- Having the **Jack and 9 of the trump suit** (the two highest trumps)
- When the "1/3 Jodi Calls" option is enabled, Jodi must be called within the **first 3 tricks**
- Calling Jodi earns a **+1 ball bonus** for your team

### Call and Loss (Optional)
- When enabled: if the bidding team loses, the opposing team gets **2 balls** instead of 1
- Toggle this in the game lobby settings

## ⚙️ Game Settings

Configure these in the lobby before starting:

| Setting | Description | Default |
|---------|-------------|---------|
| **Target Balls** | Balls needed to win the game | 12 |
| **Call and Loss** | Losing caller gives opponents 2 balls | Off |
| **1/3 Jodi Calls** | Jodi must be called in first 3 tricks | Off |

## 🛠️ Technical Details

- **Pure HTML/CSS/JavaScript** — no dependencies or build tools
- Works in any modern browser (Chrome, Firefox, Safari, Edge)
- Responsive design for desktop and tablet
- AI opponents with basic strategy
- Game log panel tracks all actions

## 📁 Project Structure

```
├── index.html    # Main HTML structure (lobby + game screens)
├── styles.css    # All styling (responsive, card designs, animations)
├── game.js       # Complete game logic (dealing, bidding, tricks, scoring, AI)
└── README.md     # This file
```

## 🚀 Getting Started

1. Clone or download this repository
2. Open `index.html` in your browser
3. Configure game settings in the lobby
4. Click **Start Game**
5. Enjoy!

## 📖 Glossary

| Term | Meaning |
|------|---------|
| **Ball** | A scoring unit; first to target balls wins |
| **Trump** | The suit chosen by the bid winner; trumps beat all other suits |
| **Trick** | One round of play where each player plays one card |
| **Royal** | Winning all tricks in a round |
| **Kunuck** | Knocking to double stakes |
| **Jodi** | Holding both J and 9 of trump |
| **Blind** | A call made before looking at your cards |
