import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/appearance.dart';
import '../widgets/game_button.dart';
import '../widgets/strategy_chart.dart';

const _commonMistakes = [
  (
    'Standing on 16 vs dealer 7, 8, 9, 10, or Ace',
    'Hit (or Surrender if late surrender is available)',
    "16 is a losing hand against a strong dealer card. Standing hopes the dealer busts, but the dealer makes a hand far more often than they bust vs a strong upcard. Hitting gives you a chance to improve.",
  ),
  (
    'Splitting 10s',
    'Stand — never split 10s',
    "A pair of 10s totals 20, one of the strongest possible hands. Splitting breaks it into two hands each starting with 10, which is weaker.",
  ),
  (
    'Not doubling 11 vs dealer 2–10',
    'Double down',
    "11 is the single best doubling opportunity in blackjack. Any 10-value card (the most common) gives you 21. Always double 11 unless the dealer shows an Ace.",
  ),
  (
    'Hitting soft 18 vs dealer 2, 7, or 8',
    'Stand',
    "Soft 18 is a strong hand. Against a 2, 7, or 8 you should stand — you're favored to win or push. Only hit soft 18 against dealer 9, 10, or Ace.",
  ),
  (
    'Not splitting 8s vs dealer 9, 10, or Ace',
    'Always split 8s',
    "A pair of 8s totals 16, the worst hand in blackjack. Splitting gives you two fresh starts with 8 as your base, which is significantly better than playing 16.",
  ),
  (
    'Standing on 12 vs dealer 2 or 3',
    'Hit',
    "Many players stand on 12 vs any dealer bust card, but 12 vs 2 or 3 is actually a hit. The dealer's bust probability isn't high enough to compensate for your weak total.",
  ),
  (
    'Not doubling soft 13–18 vs dealer 5 or 6',
    'Double down',
    "Dealer 5 and 6 are the two weakest upcards — the dealer will bust roughly 42% of the time. Any time you can double vs 5 or 6 on a soft total, you should.",
  ),
  (
    'Hitting hard 12–16 vs dealer 4, 5, or 6',
    'Stand',
    "The dealer is showing a bust card. Your job is to get out of the way and let them bust. Standing is correct when the dealer is weak.",
  ),
  (
    'Not surrendering 16 vs dealer 9, 10, or Ace',
    'Surrender (if available)',
    "Late surrender on hard 16 vs these upcards saves you money in the long run. You're expected to lose more than half your bet playing these hands.",
  ),
  (
    'Splitting 4s vs dealer cards other than 5 or 6',
    'Hit (treat as hard 8)',
    "A pair of 4s totals 8, a decent base for hitting. Only split 4s when the dealer shows 5 or 6. Otherwise, hitting is better.",
  ),
];

const _glossary = [
  ('Hard hand', 'A hand with no ace, or an ace counted as 1. Example: 10+7 = hard 17.'),
  ('Soft hand', 'A hand containing an ace counted as 11. Example: A+7 = soft 18.'),
  ('Bust', 'When your hand total exceeds 21. An automatic loss.'),
  ('Blackjack', 'An ace plus any 10-value card on the first two cards. Pays 3:2.'),
  ('Double down', 'Double your bet after the first two cards and receive exactly one more card.'),
  ('Split', 'When your first two cards are the same value, split them into two separate hands.'),
  ('Surrender', 'Fold your hand and recover half your bet. Only on the first two cards (late surrender).'),
  ('Push', 'A tie — both player and dealer have the same total. Your bet is returned.'),
  ('Basic strategy', 'The mathematically optimal decision for every player hand vs every dealer upcard.'),
  ('House edge', "The casino's mathematical advantage. With perfect basic strategy, ~0.5% on 6-deck."),
  ('Shoe', 'The device holding multiple decks. A 6-deck shoe holds 312 cards.'),
  ('Upcard', "The dealer's face-up card. Your basic strategy decisions are based on this card."),
];

class LearnPage extends ConsumerWidget {
  const LearnPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            onTap: (_) => selectionHaptic(),
            labelColor: classicGreen.gold,
            unselectedLabelColor: AppTokens.textSecondary,
            indicatorColor: classicGreen.gold,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: 'How to Play'),
              Tab(text: 'Play Smart'),
              Tab(text: 'Basic Strategy'),
              Tab(text: 'Common Mistakes'),
              Tab(text: 'Glossary'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _HowToPlayTab(),
                _PlaySmartTab(),
                _StrategyTab(),
                _MistakesTab(),
                _GlossaryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: child,
    );
  }
}

Widget _heading(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(
              color: AppTokens.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
    );

const _body = TextStyle(color: AppTokens.textSecondary, height: 1.5);

Widget _takeaway(String text) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: classicGreen.goldLight, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: classicGreen.goldLight,
                    fontWeight: FontWeight.w600,
                    height: 1.4)),
          ),
        ],
      ),
    );

/// How to play *well* — the mental models that cover most decisions without
/// memorizing the whole chart.
class _PlaySmartTab extends StatelessWidget {
  const _PlaySmartTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heading('Play decently in five ideas'),
                const Text(
                  "New to the game? Read How to Play first. Once you know the rules, you don't need to memorize the strategy chart to play well — these five ideas cover the vast majority of decisions and explain why the chart looks the way it does.",
                  style: _body,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heading('1. The dealer\'s upcard is everything'),
                const Text(
                  "Every decision starts with the dealer's face-up card. Split it into two groups:\n\n• 2–6 = weak. The dealer is likely to bust. Play it safe and let them.\n• 7, 8, 9, 10, Ace = strong. The dealer will probably make a good hand, so you need to improve yours.",
                  style: _body,
                ),
                _takeaway('Weak dealer (2–6): be cautious. Strong dealer (7–A): be aggressive.'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heading('2. Assume the hole card is a 10'),
                const Text(
                  "Ten-value cards (10, J, Q, K) are the most common in the deck — nearly a third of all cards. So assume the dealer's hidden card is a 10. That means a dealer showing 6 is probably sitting on 16 (and must hit, often busting), while a dealer showing 10 is probably on 20.",
                  style: _body,
                ),
                _takeaway('This one assumption explains most of the chart.'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heading('3. The dealer has no choices'),
                const Text(
                  "You make decisions; the dealer just follows a rule: hit until reaching 17 or more, then stop. The dealer can't get clever, can't stand early, can't react to your hand. When their upcard is weak, that forced drawing is exactly what makes them bust.",
                  style: _body,
                ),
                _takeaway('You have options the dealer doesn\'t — that\'s your edge.'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heading('4. Don\'t bust when the dealer is weak'),
                const Text(
                  "If you have a 'stiff' total (12–16) and the dealer shows 2–6, stand. Yes, 16 is a bad hand — but if you hit, you'll often bust and lose instantly. Standing puts the pressure on the weak dealer to draw and bust first. Only hit stiff hands when the dealer is strong (7–A) and you have no choice but to try to improve.",
                  style: _body,
                ),
                _takeaway('Stiff hand + weak dealer = stand and let them bust.'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heading('5. The always-and-nevers'),
                const Text(
                  "A few rules never change, no matter the dealer's card:\n\n• Always split Aces and 8s.\n• Never split 10s (you already have 20) or 5s (you have a strong 10 — double instead).\n• Always double 11 (unless the dealer shows an Ace).\n• Always hit a total of 8 or less — you can't bust.\n• Always stand on hard 17 or more.",
                  style: _body,
                ),
                _takeaway('Lock these in and you\'ll rarely make a big mistake.'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heading('Where to go next'),
                const Text(
                  "Open Basic Strategy and tap any cell — you'll see the exact play and the reasoning behind it. Then head to the Play tab: you'll get instant feedback after every decision, which is the fastest way to turn these ideas into instinct.",
                  style: _body,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// How to play — the complete rules for a total beginner.
class _HowToPlayTab extends StatelessWidget {
  const _HowToPlayTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heading('Objective'),
                const Text(
                  "Beat the dealer by getting a hand value closer to 21 without going over. You're not competing against other players — only the dealer.",
                  style: _body,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heading('Card Values'),
                const Text('2–9: face value\n10, J, Q, K: worth 10\nA: worth 1 or 11 (whichever is better)',
                    style: _body),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heading('Flow of a Hand'),
                const Text(
                  '1. Place your bet\n2. Player and dealer each get two cards (one dealer card face down)\n3. If either has blackjack, the hand may end immediately\n4. Player chooses: Hit, Stand, Double, Split, or Surrender\n5. If the player doesn\'t bust, the dealer reveals and plays\n6. Dealer must hit until reaching 17 or higher\n7. Whoever is closer to 21 without busting wins',
                  style: _body,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heading('Your Options'),
                const Text(
                  '• Hit — take another card.\n• Stand — keep your total and end your turn.\n• Double — double your bet and take exactly one more card.\n• Split — if your two cards match, split them into two hands (with a second bet).\n• Surrender — give up the hand and get half your bet back (only some games allow this).',
                  style: _body,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heading('Payouts'),
                const Text(
                  'Win: 1:1 (win \$10 on a \$10 bet)\nBlackjack: 3:2 (win \$15 on a \$10 bet)\nPush: bet returned\nSurrender: half bet returned',
                  style: _body,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heading('Dealer Rules'),
                const Text(
                  'The dealer has no choices — they follow fixed rules. The dealer must hit until their hand totals 17 or more. Under Vegas Strip rules the dealer stands on soft 17, which slightly favors the player.',
                  style: _body,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StrategyTab extends StatelessWidget {
  const _StrategyTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading('Basic Strategy'),
          const Text(
            'The mathematically optimal decision for every hand vs the dealer\'s upcard. Perfect basic strategy reduces the house edge to ~0.5% on a 6-deck game. Tap any cell for an explanation.',
            style: _body,
          ),
          const SizedBox(height: 16),
          const StrategyChart(),
        ],
      ),
    );
  }
}

class _MistakesTab extends StatelessWidget {
  const _MistakesTab();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _commonMistakes.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final (scenario, correct, why) = _commonMistakes[i];
        return _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: classicGreen.gold,
                    child: Text('${i + 1}',
                        style: TextStyle(
                            color: classicGreen.feltDark,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(scenario,
                        style: const TextStyle(
                            color: AppTokens.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Correct play: $correct',
                  style: TextStyle(color: classicGreen.goldLight, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(why, style: _body),
            ],
          ),
        );
      },
    );
  }
}

class _GlossaryTab extends StatelessWidget {
  const _GlossaryTab();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _glossary.length,
      separatorBuilder: (context, index) => const Divider(color: Color(0x22FFFFFF)),
      itemBuilder: (context, i) {
        final (term, def) = _glossary[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(term,
                style: TextStyle(
                    color: classicGreen.gold, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text(def, style: _body),
          ],
        );
      },
    );
  }
}
