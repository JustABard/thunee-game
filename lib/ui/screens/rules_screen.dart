import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Interactive rules reference screen
class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('How to Play'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _RuleSection(
            icon: Icons.info_outline,
            title: 'Game Overview',
            content: 'Thunee is a traditional South African trick-taking card game played with 4 players in 2 teams of 2. '
                'The goal is to be the first team to reach 12 balls (or 13 if Kunuck is called).',
          ),

          _RuleSection(
            icon: Icons.style,
            title: 'The Deck',
            content: 'Thunee uses a 24-card deck:\n'
                '• 4 suits: Hearts ♥, Diamonds ♦, Clubs ♣, Spades ♠\n'
                '• 6 ranks per suit: J, 9, A, 10, K, Q\n\n'
                'Card Points:\n'
                '• Jack (J) = 30 points\n'
                '• Nine (9) = 20 points\n'
                '• Ace (A) = 11 points\n'
                '• Ten (10) = 10 points\n'
                '• King (K) = 3 points\n'
                '• Queen (Q) = 2 points\n\n'
                'Total: 76 points per suit, 304 points in deck',
          ),

          _RuleSection(
            icon: Icons.gavel,
            title: 'Bidding Phase',
            content: 'After cards are dealt, players bid for the right to choose trump:\n'
                '• Starting bid: 10 points\n'
                '• Bids increase in increments of 10\n'
                '• Maximum bid: 50 points\n'
                '• Players can pass if they don\'t want to bid\n'
                '• The highest bidder\'s team becomes the "counting team"\n'
                '• The other team is the "non-counting team"',
          ),

          _RuleSection(
            icon: Icons.play_arrow,
            title: 'Playing Tricks',
            content: 'Each round consists of 6 tricks:\n'
                '• Players must follow suit if possible\n'
                '• Trump cards beat all non-trump cards\n'
                '• The highest trump wins the trick\n'
                '• If no trump, highest card of led suit wins\n'
                '• Winner of trick leads the next trick\n'
                '• Last trick awards +10 bonus points',
          ),

          _RuleSection(
            icon: Icons.emoji_events,
            title: 'Normal Ranking',
            content: 'Trick strength (highest to lowest):\n'
                '• Jack (J)\n'
                '• Nine (9)\n'
                '• Ace (A)\n'
                '• Ten (10)\n'
                '• King (K)\n'
                '• Queen (Q)',
          ),

          _RuleSection(
            icon: Icons.swap_vert,
            title: 'Royals Ranking',
            content: 'When Royals is called, ranking reverses:\n'
                '• Queen (Q) - highest!\n'
                '• King (K)\n'
                '• Ten (10)\n'
                '• Ace (A)\n'
                '• Nine (9)\n'
                '• Jack (J) - lowest!',
            color: Colors.purple,
          ),

          _RuleSection(
            icon: Icons.calculate,
            title: 'Scoring',
            content: 'After all 6 tricks are played:\n'
                '• Count each team\'s card points\n'
                '• If counting team reaches their bid (or 105+), they get balls\n'
                '• Otherwise, non-counting team gets balls\n'
                '• Balls awarded based on point difference:\n'
                '  - Below 140: +1 ball\n'
                '  - 140-169: +2 balls\n'
                '  - 170-199: +3 balls\n'
                '  - 200+: +4 balls',
          ),

          _RuleSection(
            icon: Icons.bolt,
            title: 'Thunee',
            content: 'A bold special call where you try to win ALL 6 tricks:\n'
                '• Called after 6 cards are dealt\n'
                '• Success: Caller wins all 6 tricks → +4 balls\n'
                '• Failure: Opponent wins any trick → opponents +4 balls\n'
                '• Partner Catch: Partner wins any trick → opponents +8 balls!\n'
                '• No bidding when Thunee is called',
            color: Colors.orange,
          ),

          _RuleSection(
            icon: Icons.visibility_off,
            title: 'Blind Thunee/Royals',
            content: 'Call Thunee or Royals before seeing all your cards:\n'
                '• Called after only 4 cards are dealt\n'
                '• Remaining 2 cards stay hidden\n'
                '• Hidden cards revealed after winning 4 tricks\n'
                '• Success: +8 balls (configurable 4-10)\n'
                '• Failure/Partner catch: Same as regular Thunee/Royals',
            color: Colors.indigo,
          ),

          _RuleSection(
            icon: Icons.casino,
            title: 'Jodi',
            content: 'Call when you hold specific combinations:\n'
                '• King + Queen of same suit = 20 points (40 if trump)\n'
                '• Jack + Queen + King of same suit = 30 points (50 if trump)\n'
                '• Can be called on tricks 1 or 3 (if setting enabled)\n'
                '• Must actually hold the cards!\n'
                '• Points add to your team\'s total',
            color: Colors.teal,
          ),

          _RuleSection(
            icon: Icons.exposure_plus_2,
            title: 'Double',
            content: 'Last trick gamble:\n'
                '• Called before playing the 6th trick\n'
                '• Success: Win the trick → +2 balls\n'
                '• Failure: Lose the trick → opponents +4 balls\n'
                '• High risk, high reward!',
            color: Colors.red,
          ),

          _RuleSection(
            icon: Icons.star,
            title: 'Kunuck',
            content: 'Final trick call that changes the match:\n'
                '• Called on the last (6th) trick\n'
                '• Success: Win the trick → +3 balls\n'
                '• Failure: Lose the trick → opponents +4 balls\n'
                '• Match target increases from 12 to 13 balls',
            color: Colors.amber,
          ),

          _RuleSection(
            icon: Icons.settings,
            title: 'House Rules',
            content: 'Customizable settings:\n'
                '• Enable/disable special calls\n'
                '• Call Over Teammates: Allow outbidding partners\n'
                '• Call & Loss: Losing trump team gives +2 balls\n'
                '• Jodi restrictions: First & third tricks only\n'
                '• Blind call ball values: 4-10 (default 8)\n'
                '• Match target: 10-15 balls (default 12)',
          ),

          const SizedBox(height: 32),

          // Strategy tips
          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Strategy Tips',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '• Bid conservatively unless you have strong trump cards\n'
                    '• Remember which cards have been played\n'
                    '• NEVER cut your partner during Thunee/Royals\n'
                    '• Save high trump for critical moments\n'
                    '• Use Jodi to boost your team over 105 threshold\n'
                    '• Call Double only when confident of winning\n'
                    '• Blind calls are risky but can win matches quickly',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ).animate().fadeIn(duration: const Duration(milliseconds: 300)),
    );
  }
}

class _RuleSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  final Color? color;

  const _RuleSection({
    required this.icon,
    required this.title,
    required this.content,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final sectionColor = color ?? Theme.of(context).colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: Icon(icon, color: sectionColor),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: sectionColor,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              content,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
