import 'dart:math';

import 'package:flutter/material.dart' hide Action;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/cards.dart' as bj;
import '../../engine/strategy.dart';
import '../../engine/variants.dart';
import '../../state/achievements_provider.dart';
import '../../state/appearance_provider.dart';
import '../../state/learn_provider.dart';
import '../../state/settings_provider.dart';
import '../../state/stats_provider.dart';
import '../../state/store_provider.dart';
import '../theme/appearance.dart';
import '../widgets/game_button.dart';
import '../widgets/playing_card.dart';
import '../widgets/strategy_chart.dart';
import 'shop_page.dart';

// ---------------------------------------------------------------------------
// Shared card / text helpers
// ---------------------------------------------------------------------------

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(20),
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

const _body = TextStyle(color: AppTokens.textSecondary, fontSize: 14, height: 1.5);

Widget _takeaway(String text, Color color) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: color, size: 17),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w600, fontSize: 14, height: 1.4)),
          ),
        ],
      ),
    );

// ---------------------------------------------------------------------------
// Lesson model + content
// ---------------------------------------------------------------------------

class _Step {
  final String heading;
  final String? body;
  final String? takeaway;
  final Widget? widget;
  const _Step({required this.heading, this.body, this.takeaway, this.widget});
}

class _Lesson {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;

  /// Opens the interactive scenario drill instead of the paged lesson, and is
  /// excluded from the lesson-completion progress (it's a tool, not a lesson).
  final bool isPractice;
  final List<_Step> Function(RuleSet rs) build;
  const _Lesson({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.build,
    this.isPractice = false,
  });
}

List<_Step> _basics(RuleSet rs) {
  final surr = rs.surrender != Surrender.none;
  final bjWin = (10 * blackjackPayoutMultiplier(rs.blackjackPays)).round();
  return [
    _Step(
      heading: 'The goal',
      body:
          "It's just you against the dealer — other players don't matter. Get your hand as close to 21 as you can without going over. Go over and you 'bust' and lose instantly. Otherwise, whoever is closer to 21 wins.",
    ),
    _Step(
      heading: 'What the cards are worth',
      body:
          '• 2–9: their face value\n• 10, J, Q, K: worth 10\n• Ace: worth 1 or 11 — whichever helps, and it can switch automatically as you draw.',
      takeaway:
          'An Ace + any 10-value card on your first two cards is a "blackjack" — the best hand.',
      widget: const _ExampleHand([
        ('worth 9', [bj.Card(rank: '9', suit: '♦')]),
        ('worth 10', [bj.Card(rank: 'Q', suit: '♠')]),
        ('1 or 11', [bj.Card(rank: 'A', suit: '♥')]),
      ]),
    ),
    _Step(
      heading: 'How a hand plays out',
      body:
          "1. You place a bet.\n2. You get two cards face up; the dealer gets one up (the 'upcard') and one hidden.\n3. You act — take cards until you stand or bust.\n4. The dealer reveals the hidden card and must draw to 17 or more.\n5. Closest to 21 without busting wins. A tie is a 'push' and your bet comes back.",
    ),
    _Step(
      heading: 'Your moves',
      body:
          '• Hit — take another card.\n• Stand — keep your total, end your turn.\n• Double — double your bet and take exactly one more card.\n• Split — matching cards become two separate hands.'
          '${surr ? '\n• Surrender — give up the hand, get half your bet back.' : ''}',
      takeaway: 'Knowing when to use each move is the whole game — the next lessons teach it.',
    ),
    _Step(
      heading: 'Payouts',
      body:
          'Win: pays 1:1 — bet \$10, win \$10.\nBlackjack: pays ${blackjackPayoutId(rs.blackjackPays)} — bet \$10, win \$$bjWin.\nPush (tie): your bet is returned.'
          '${surr ? '\nSurrender: half your bet back.' : ''}',
    ),
  ];
}

List<_Step> _dealer(RuleSet rs) => [
      _Step(
        heading: "The dealer's upcard is everything",
        body:
            "Every decision starts with the dealer's face-up card:\n\n• 2–6 = weak. The dealer is likely to bust — play it safe and let them.\n• 7, 8, 9, 10, Ace = strong. The dealer will probably make a good hand — you need to improve yours.",
        takeaway: 'Weak dealer (2–6): be cautious. Strong dealer (7–A): be aggressive.',
        widget: const _ExampleHand([
          ('Weak', [bj.Card(rank: '6', suit: '♦')]),
          ('Strong', [bj.Card(rank: 'K', suit: '♠')]),
        ]),
      ),
      _Step(
        heading: 'Assume the hole card is a 10',
        body:
            "Ten-value cards are nearly a third of the deck, so assume the dealer's hidden card is a 10. A dealer showing 6 is probably sitting on 16 (must hit, often busts); a dealer showing 10 is probably on 20.",
        takeaway: 'This one assumption explains most of basic strategy.',
      ),
      _Step(
        heading: 'The dealer has no choices',
        body:
            "You make decisions; the dealer just follows a rule — draw until 17 or more, then stop. In this game the dealer ${rs.dealerHitsSoft17 ? 'hits' : 'stands on'} soft 17. When the upcard is weak, that forced drawing is exactly what makes them bust.",
        takeaway: "You have options the dealer doesn't — that's your edge.",
      ),
    ];

List<_Step> _hitStand(RuleSet rs) => [
      _Step(
        heading: "Don't bust when the dealer is weak",
        body:
            "With a 'stiff' total (12–16) against a dealer showing 2–6, stand. Yes, 16 is a bad hand — but if you hit you'll often bust and lose instantly. Standing makes the weak dealer draw and bust first.",
        takeaway: 'Stiff hand + weak dealer = stand and let them bust.',
        widget: const _ExampleHand([
          ('You have', [bj.Card(rank: '10', suit: '♠'), bj.Card(rank: '6', suit: '♥')]),
          ('Dealer', [bj.Card(rank: '6', suit: '♦')]),
        ]),
      ),
      _Step(
        heading: 'Hit when the dealer is strong',
        body:
            "Against a dealer showing 7–A, standing on a stiff total just loses — the dealer will usually make 17 or better. You have to draw and try to improve, even at the risk of busting.",
        takeaway: 'Stiff hand + strong dealer = hit and try to improve.',
        widget: const _ExampleHand([
          ('You have', [bj.Card(rank: '10', suit: '♠'), bj.Card(rank: '6', suit: '♥')]),
          ('Dealer', [bj.Card(rank: '9', suit: '♣')]),
        ]),
      ),
      _Step(
        heading: 'The easy calls',
        body:
            "• 8 or less: always hit — you can't bust.\n• Hard 17 or more: always stand.\n• Soft hands (with an Ace) can't bust on a single hit, so they're much safer to draw.",
      ),
    ];

List<_Step> _doubleSplit(RuleSet rs) => [
      _Step(
        heading: 'Doubling down',
        body:
            "Double when you're in a strong spot and the dealer is weak — above all on 11, and on 10 (except against a 10 or Ace). You put more money out exactly when the odds favor you, and take one more card.",
        takeaway: 'Always double 11 (except against an Ace).',
        widget: const _ExampleHand([
          ('You have', [bj.Card(rank: '6', suit: '♦'), bj.Card(rank: '5', suit: '♠')]),
          ('Dealer', [bj.Card(rank: '5', suit: '♥')]),
        ]),
      ),
      _Step(
        heading: 'The always-and-nevers of splitting',
        body:
            '• Always split Aces and 8s.\n• Never split 10s (you already have 20) or 5s (treat them as a strong 10 and double instead).\n• Other pairs depend on the dealer — the chart has the details.',
        takeaway: 'Split A/8, never 10/5. Lock these in and you\'ll rarely make a big mistake.',
        widget: const _ExampleHand([
          ('Always split', [bj.Card(rank: '8', suit: '♠'), bj.Card(rank: '8', suit: '♥')]),
          ('Never split', [bj.Card(rank: '10', suit: '♦'), bj.Card(rank: 'K', suit: '♣')]),
        ]),
      ),
    ];

List<_Step> _chartLesson(RuleSet rs) => [
      _Step(
        heading: 'The complete answer key',
        body:
            "You've built the intuition — this chart is the exact optimal move for every hand versus every dealer upcard. Tap any cell to see the play and the reasoning. It updates to match your current game rules.",
        widget: const StrategyChart(),
      ),
    ];

/// One or more labeled example hands rendered in the current theme, shown
/// inside a lesson step to make the idea concrete. The total is shown for
/// multi-card hands; single cards rely on their label.
class _ExampleHand extends ConsumerWidget {
  final List<(String, List<bj.Card>)> groups;
  const _ExampleHand(this.groups);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appearanceProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.feltBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (label, cards) in groups) _group(theme, label, cards),
        ],
      ),
    );
  }

  Widget _group(AppearanceTheme theme, String label, List<bj.Card> cards) {
    final hv = bj.handValue(cards);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                color: AppTokens.textSecondary,
                fontSize: 11,
                letterSpacing: 1,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < cards.length; i++)
              Padding(
                padding: EdgeInsets.only(right: i < cards.length - 1 ? 4 : 0),
                child: PlayingCardView(card: cards[i], theme: theme, width: 42),
              ),
          ],
        ),
        if (cards.length >= 2) ...[
          const SizedBox(height: 8),
          Text(hv.soft && hv.total != 21 ? 'Soft ${hv.total}' : '${hv.total}',
              style: const TextStyle(
                  color: AppTokens.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ],
    );
  }
}

final List<_Lesson> _lessons = [
  _Lesson(
    id: 'basics',
    title: 'The Basics',
    subtitle: 'Goal, cards, and your moves',
    icon: Icons.menu_book_outlined,
    build: _basics,
  ),
  _Lesson(
    id: 'dealer',
    title: 'Reading the Dealer',
    subtitle: 'Weak vs strong upcards',
    icon: Icons.visibility_outlined,
    build: _dealer,
  ),
  _Lesson(
    id: 'hitstand',
    title: 'Hit or Stand',
    subtitle: 'The core decision',
    icon: Icons.back_hand_outlined,
    build: _hitStand,
  ),
  _Lesson(
    id: 'doublesplit',
    title: 'Doubles & Splits',
    subtitle: 'The always-and-nevers',
    icon: Icons.call_split,
    build: _doubleSplit,
  ),
  _Lesson(
    id: 'chart',
    title: 'The Strategy Chart',
    subtitle: 'The complete answer key',
    icon: Icons.grid_on,
    build: _chartLesson,
  ),
  _Lesson(
    id: 'quiz',
    title: 'Test Yourself',
    subtitle: 'Drill any hand vs any dealer',
    icon: Icons.quiz_outlined,
    build: (_) => const [],
    isPractice: true,
  ),
];

// ---------------------------------------------------------------------------
// Learn home — the path
// ---------------------------------------------------------------------------

class LearnPage extends ConsumerWidget {
  const LearnPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appearanceProvider);
    final done = ref.watch(learnProvider);
    final isPremium = ref.watch(entitlementsProvider).isPremium;

    final teachable = _lessons.where((l) => !l.isPractice).toList();
    final completed = teachable.where((l) => done.contains(l.id)).length;
    final nextId = teachable
        .cast<_Lesson?>()
        .firstWhere((l) => !done.contains(l!.id), orElse: () => null)
        ?.id;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Learn to play',
                  style: TextStyle(
                      color: AppTokens.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            TextButton.icon(
              onPressed: withHaptic(() => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ReferenceScreen()),
                  )),
              icon: Icon(Icons.menu_book, size: 18, color: theme.gold),
              label: Text('Reference', style: TextStyle(color: theme.gold)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _ProgressCard(theme: theme, completed: completed, total: teachable.length),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _ActionCard(
                  theme: theme,
                  icon: _lessons.firstWhere((l) => l.isPractice).icon,
                  title: 'Test Yourself',
                  subtitle: 'Drill any hand',
                  locked: !isPremium,
                  onTap: isPremium
                      ? () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const PracticeScreen()),
                          )
                      : () => openGoPro(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionCard(
                  theme: theme,
                  icon: Icons.bolt,
                  title: 'Cheat Sheet',
                  subtitle: 'The 95% in one page',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CheatSheetScreen()),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Lessons unlock in order: a lesson is available only once every earlier
        // one is done. Since [nextId] is the first incomplete lesson, everything
        // before it is done (unlocked) and everything after it stays locked.
        ...teachable.map((lesson) {
          final isDone = done.contains(lesson.id);
          final locked = !isDone && lesson.id != nextId;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _LessonTile(
              theme: theme,
              lesson: lesson,
              done: isDone,
              recommended: lesson.id == nextId,
              locked: locked,
              onTap: locked
                  ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Finish the previous lesson to unlock this one.'),
                      ))
                  : () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => _LessonScreen(lesson: lesson)),
                      ),
            ),
          );
        }),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final AppearanceTheme theme;
  final int completed;
  final int total;
  const _ProgressCard({required this.theme, required this.completed, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : completed / total;
    final allDone = completed >= total && total > 0;
    return _Card(
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: CircularProgressIndicator(
                    value: pct,
                    strokeWidth: 5,
                    backgroundColor: const Color(0x22FFFFFF),
                    valueColor: AlwaysStoppedAnimation(theme.gold),
                  ),
                ),
                Text('$completed/$total',
                    style: const TextStyle(
                        color: AppTokens.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(allDone ? "You've got the fundamentals" : 'Your progress',
                    style: const TextStyle(
                        color: AppTokens.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                Text(
                  allDone
                      ? 'Revisit any lesson or open the Reference anytime.'
                      : 'Short lessons that take you from the rules to playing well.',
                  style: const TextStyle(
                      color: AppTokens.textSecondary, fontSize: 13, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  final AppearanceTheme theme;
  final _Lesson lesson;
  final bool done;
  final bool recommended;
  final bool locked;
  final VoidCallback? onTap;
  const _LessonTile({
    required this.theme,
    required this.lesson,
    required this.done,
    required this.recommended,
    this.locked = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap == null ? null : withHaptic(onTap!),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: recommended ? theme.gold : const Color(0x18FFFFFF),
            width: recommended ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Opacity(
              opacity: locked ? 0.4 : 1,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: done ? theme.gold.withValues(alpha: 0.18) : const Color(0x24FFFFFF),
                  borderRadius: BorderRadius.circular(11),
                ),
                child:
                    Icon(lesson.icon, size: 20, color: done ? theme.gold : AppTokens.textPrimary),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Opacity(
                opacity: locked ? 0.4 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lesson.title,
                        style: const TextStyle(
                            color: AppTokens.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(lesson.subtitle,
                        style: const TextStyle(color: AppTokens.textSecondary, fontSize: 12.5)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            _trailing(),
          ],
        ),
      ),
    );
  }

  Widget _trailing() {
    if (locked) {
      return const Icon(Icons.lock_outline, color: AppTokens.textSecondary, size: 20);
    }
    if (lesson.isPractice) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.gold, width: 1.5),
        ),
        child: Text('Practice',
            style: TextStyle(color: theme.gold, fontSize: 12, fontWeight: FontWeight.bold)),
      );
    }
    if (done) return Icon(Icons.check_circle, color: theme.gold, size: 22);
    if (recommended) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: theme.gold, borderRadius: BorderRadius.circular(20)),
        child: Text('Start',
            style: TextStyle(color: theme.feltDark, fontSize: 12, fontWeight: FontWeight.bold)),
      );
    }
    return const Icon(Icons.chevron_right, color: AppTokens.textSecondary, size: 22);
  }
}

// ---------------------------------------------------------------------------
// Lesson screen — paged one-idea steps
// ---------------------------------------------------------------------------

class _LessonScreen extends ConsumerStatefulWidget {
  final _Lesson lesson;
  const _LessonScreen({required this.lesson});

  @override
  ConsumerState<_LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<_LessonScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(appearanceProvider);
    final rs = ref.watch(settingsProvider).ruleSet;
    final steps = widget.lesson.build(rs);
    final last = _index >= steps.length - 1;

    return Scaffold(
      backgroundColor: theme.feltDark,
      appBar: AppBar(
        backgroundColor: theme.feltDark,
        foregroundColor: AppTokens.textPrimary,
        elevation: 0,
        title: Text(widget.lesson.title, style: const TextStyle(fontSize: 17)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                for (var i = 0; i < steps.length; i++)
                  Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: i == steps.length - 1 ? 0 : 6),
                      decoration: BoxDecoration(
                        color: const Color(0x22FFFFFF),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: AnimatedFractionallySizedBox(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOut,
                          alignment: Alignment.centerLeft,
                          widthFactor: i <= _index ? 1.0 : 0.0,
                          heightFactor: 1.0,
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: theme.gold),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (i) => setState(() => _index = i),
              itemCount: steps.length,
              itemBuilder: (context, i) => _StepView(step: steps[i], goldLight: theme.goldLight),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Row(
              children: [
                if (_index > 0)
                  TextButton(
                    onPressed: withHaptic(() => _controller.previousPage(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOut,
                        )),
                    child: const Text('Back', style: TextStyle(color: AppTokens.textSecondary)),
                  ),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.gold,
                    foregroundColor: theme.feltDark,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  ),
                  onPressed: withHaptic(() {
                    if (last) {
                      ref.read(learnProvider.notifier).markComplete(widget.lesson.id);
                      ref.read(achievementsProvider.notifier).evaluate();
                      Navigator.of(context).pop();
                    } else {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOut,
                      );
                    }
                  }),
                  child: Text(last ? 'Done' : 'Next',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepView extends StatelessWidget {
  final _Step step;
  final Color goldLight;
  const _StepView({required this.step, required this.goldLight});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading(step.heading),
            if (step.body != null) Text(step.body!, style: _body),
            if (step.takeaway != null) _takeaway(step.takeaway!, goldLight),
            if (step.widget != null) ...[
              const SizedBox(height: 14),
              step.widget!,
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reference — strategy chart + glossary, available anytime
// ---------------------------------------------------------------------------

const _glossary = [
  ('Hard hand', 'A hand with no ace, or an ace counted as 1. Example: 10+7 = hard 17.'),
  ('Soft hand', 'A hand containing an ace counted as 11. Example: A+7 = soft 18.'),
  ('Bust', 'When your hand total exceeds 21 — an automatic loss.'),
  ('Blackjack', 'An ace plus any 10-value card on the first two cards — the strongest hand, and it pays a bonus.'),
  ('Double down', 'Double your bet after the first two cards and receive exactly one more card.'),
  ('Split', 'When your first two cards are the same value, split them into two separate hands.'),
  ('Surrender', 'Fold your hand and recover half your bet. Only on the first two cards (late surrender).'),
  ('Push', 'A tie — both player and dealer have the same total. Your bet is returned.'),
  ('Basic strategy', 'The mathematically optimal decision for every player hand vs every dealer upcard.'),
  ('House edge', "The casino's mathematical advantage. With perfect basic strategy, ~0.5% on 6-deck."),
  ('Shoe', 'The device holding multiple decks. A 6-deck shoe holds 312 cards.'),
  ('Upcard', "The dealer's face-up card. Your basic strategy decisions are based on this card."),
];

class ReferenceScreen extends ConsumerWidget {
  const ReferenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appearanceProvider);
    return Scaffold(
      backgroundColor: theme.feltDark,
      appBar: AppBar(
        backgroundColor: theme.feltDark,
        foregroundColor: AppTokens.textPrimary,
        elevation: 0,
        title: const Text('Reference', style: TextStyle(fontSize: 17)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          _CheatSheetTile(theme: theme),
          const SizedBox(height: 16),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heading('Basic strategy chart'),
                const Text(
                  'The optimal decision for every hand vs the dealer\'s upcard, for your current rules. Tap any cell for the play and the reasoning.',
                  style: _body,
                ),
                const SizedBox(height: 14),
                const StrategyChart(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heading('Glossary'),
                for (var i = 0; i < _glossary.length; i++) ...[
                  if (i > 0)
                    Container(
                      height: 1,
                      color: const Color(0x12FFFFFF),
                      margin: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  Text(_glossary[i].$1,
                      style: TextStyle(
                          color: theme.gold, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(_glossary[i].$2, style: _body),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cheat sheet — the ~95% of blackjack intuition on one scannable screen
// ---------------------------------------------------------------------------

/// Compact tappable tile used for the side-by-side Test Yourself / Cheat Sheet
/// shortcuts on the Learn home. Flat gold-tinted card, no gradient.
class _ActionCard extends StatelessWidget {
  final AppearanceTheme theme;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool locked;
  final VoidCallback onTap;
  const _ActionCard({
    required this.theme,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: withHaptic(onTap),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.gold.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.gold.withValues(alpha: 0.45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.gold.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 22, color: theme.goldLight),
                ),
                const Spacer(),
                if (locked)
                  Icon(Icons.lock_outline, size: 16, color: theme.gold.withValues(alpha: 0.85)),
              ],
            ),
            const SizedBox(height: 10),
            Text(title,
                style: const TextStyle(
                    color: AppTokens.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(color: AppTokens.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _CheatSheetTile extends StatelessWidget {
  final AppearanceTheme theme;
  const _CheatSheetTile({required this.theme});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: withHaptic(() => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CheatSheetScreen()),
          )),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.gold.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.gold.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.gold.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(Icons.bolt, size: 22, color: theme.gold),
            ),
            const SizedBox(width: 13),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cheat Sheet',
                      style: TextStyle(
                          color: AppTokens.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text('The 95% in one page — a quick check or refresher',
                      style: TextStyle(color: AppTokens.textSecondary, fontSize: 12.5)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: theme.gold, size: 22),
          ],
        ),
      ),
    );
  }
}

class CheatSheetScreen extends ConsumerWidget {
  const CheatSheetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appearanceProvider);
    return Scaffold(
      backgroundColor: theme.feltDark,
      appBar: AppBar(
        backgroundColor: theme.feltDark,
        foregroundColor: AppTokens.textPrimary,
        elevation: 0,
        title: const Text('Cheat Sheet', style: TextStyle(fontSize: 17)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [_CheatSheet(theme: theme)],
      ),
    );
  }
}

class _CheatSheet extends StatelessWidget {
  final AppearanceTheme theme;
  const _CheatSheet({required this.theme});

  @override
  Widget build(BuildContext context) {
    final gold = theme.gold;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'The quick rules of thumb that cover the vast majority of decisions. For exact edge cases, see the strategy chart.',
            style: _body,
          ),
          const SizedBox(height: 16),
          _section('Read the dealer', gold, [
            _bullet('2–6 = weak — the dealer often busts. Play it safe.'),
            _bullet('7, 8, 9, 10, A = strong — you need to improve your hand.'),
            _bullet("Assume the dealer's hidden card is a 10."),
          ]),
          _section('Hard totals', gold, [
            _rule('8 or less', 'Always hit'),
            _rule('9', 'Double vs 3–6, else hit'),
            _rule('10', 'Double vs 2–9, else hit'),
            _rule('11', 'Double (hit vs Ace)'),
            _rule('12', 'Stand vs 4–6, else hit'),
            _rule('13–16', 'Stand vs 2–6, hit vs 7–A'),
            _rule('17+', 'Always stand'),
          ]),
          _section('Soft totals (Ace + card)', gold, [
            _rule('A,2 – A,6', 'Hit — double vs 5–6'),
            _rule('A,7', 'Stand vs 2/7/8, double vs 3–6, hit vs 9/10/A'),
            _rule('A,8 – A,9', 'Always stand'),
          ]),
          _section('Pairs', gold, [
            _rule('A,A · 8,8', 'Always split'),
            _rule('10,10 · 5,5', 'Never split'),
            _rule('9,9', 'Split, except stand vs 7/10/A'),
            _rule('2,2·3,3·7,7', 'Split vs 2–7'),
            _rule('6,6', 'Split vs 2–6'),
            _rule('4,4', 'Split only vs 5–6'),
          ]),
          _section('Golden rules', gold, [
            _bullet('Never take insurance.'),
            _bullet('When unsure, mirror the dealer: weak dealer → play safe, strong dealer → take risks.'),
            _bullet('Doubling is strongest on 11 and 10.'),
          ], last: true),
        ],
      ),
    );
  }

  Widget _section(String title, Color gold, List<Widget> rows, {bool last = false}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: TextStyle(
                  color: gold, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 8),
          ...rows,
          if (!last) const SizedBox(height: 16),
        ],
      );

  Widget _rule(String cond, String action) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 92,
              child: Text(cond,
                  style: const TextStyle(
                      color: AppTokens.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(action,
                  style: const TextStyle(
                      color: AppTokens.textSecondary, fontSize: 13, height: 1.4)),
            ),
          ],
        ),
      );

  Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('•  ',
                style: TextStyle(color: AppTokens.textSecondary, fontSize: 13, height: 1.4)),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      color: AppTokens.textSecondary, fontSize: 13, height: 1.4)),
            ),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// Test Yourself — endless, procedurally-generated single-decision drills
// ---------------------------------------------------------------------------

const _feltGreen = Color(0xFF27AE60);
const _lightGreen = Color(0xFF6EE7B7);
const _feltRed = Color(0xFFC0392B);
const _lightRed = Color(0xFFFC8181);

const _dealers = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'A'];

String _actionLabel(Action a) => switch (a) {
      Action.hit => 'Hit',
      Action.stand => 'Stand',
      Action.double => 'Double',
      Action.split => 'Split',
      Action.surrender => 'Surrender',
    };

List<DealScenario> _hardPool(int lo, int hi) => [
      for (var t = lo; t <= hi; t++)
        for (final d in _dealers) DealScenario(HandType.hard, t, d),
    ];

List<DealScenario> _softPool(int lo, int hi) => [
      for (var t = lo; t <= hi; t++)
        for (final d in _dealers) DealScenario(HandType.soft, t, d),
    ];

List<DealScenario> _pairPool() => [
      for (final r in ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'A'])
        for (final d in _dealers) DealScenario(HandType.pair, r, d),
    ];

/// A themed drill defined by a *pool* of chart cells rather than a fixed list —
/// the runner samples from it endlessly, so practice never runs out. The right
/// answer for each hand comes from basic strategy for the current rules.
class _DrillSet {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<DealScenario> Function() pool;

  /// Traps: sample only decision-boundary cells (drop the obvious ones).
  final bool trickyOnly;

  const _DrillSet({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.pool,
    this.trickyOnly = false,
  });
}

final List<_DrillSet> _drillSets = [
  _DrillSet(
    id: 'stiff',
    title: 'Stiff Hands',
    subtitle: 'Hit or stand on 12–16',
    icon: Icons.back_hand_outlined,
    pool: () => _hardPool(12, 16),
  ),
  _DrillSet(
    id: 'soft',
    title: 'Soft Hands',
    subtitle: 'Playing an Ace as 11',
    icon: Icons.auto_awesome_outlined,
    pool: () => _softPool(13, 19),
  ),
  _DrillSet(
    id: 'double',
    title: 'Doubling Down',
    subtitle: 'When to press your bet',
    icon: Icons.trending_up,
    pool: () => [..._hardPool(8, 11), ..._softPool(13, 18)],
  ),
  _DrillSet(
    id: 'split',
    title: 'Splitting Pairs',
    subtitle: 'Which pairs to split',
    icon: Icons.call_split,
    pool: _pairPool,
  ),
  _DrillSet(
    id: 'traps',
    title: 'Trap Hands',
    subtitle: 'The tricky calls people get wrong',
    icon: Icons.report_problem_outlined,
    pool: () => [..._hardPool(8, 17), ..._softPool(13, 20), ..._pairPool()],
    trickyOnly: true,
  ),
];

/// One concrete hand realized from a [DealScenario] — the dealer upcard and the
/// player's two cards, plus the category (so Split is offered only for pairs).
class _Hand {
  final bj.Card dealer;
  final bj.Card p1;
  final bj.Card p2;
  final HandType type;
  const _Hand({required this.dealer, required this.p1, required this.p2, required this.type});
}

_Hand _buildHand(DealScenario s, Random rng) {
  final (r1, r2) = scenarioPlayerRanks(s.handType, s.value);
  final s1 = bj.suits[rng.nextInt(4)];
  var s2 = bj.suits[rng.nextInt(4)];
  if (r1 == r2) {
    while (s2 == s1) {
      s2 = bj.suits[rng.nextInt(4)];
    }
  }
  return _Hand(
    dealer: bj.Card(rank: s.dealerUpcard, suit: bj.suits[rng.nextInt(4)]),
    p1: bj.Card(rank: r1, suit: s1),
    p2: bj.Card(rank: r2, suit: s2),
    type: s.handType,
  );
}

bool _sameCell(DealScenario a, DealScenario b) =>
    a.handType == b.handType && a.value == b.value && a.dealerUpcard == b.dealerUpcard;

/// Samples the next hand from a drill's pool, weighted toward decision-boundary
/// cells (so the hard calls come up more than the obvious ones) and never
/// repeating [avoid] — the cell just shown — back-to-back.
DealScenario _sample(_DrillSet drill, RuleSet rs, Random rng, DealScenario? avoid) {
  final weighted = <DealScenario>[];
  for (final c in drill.pool()) {
    if (avoid != null && _sameCell(c, avoid)) continue;
    final tier = decisionDifficulty(c.handType, c.value, c.dealerUpcard, rs);
    if (drill.trickyOnly && tier == 'easy') continue;
    final w = tier == 'hard' ? 3 : (tier == 'medium' ? 2 : 1);
    for (var i = 0; i < w; i++) {
      weighted.add(c);
    }
  }
  if (weighted.isEmpty) {
    final all = drill.pool();
    return all[rng.nextInt(all.length)];
  }
  return weighted[rng.nextInt(weighted.length)];
}

/// Catalog of drills, presented like the lesson list.
class PracticeScreen extends ConsumerWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appearanceProvider);
    return Scaffold(
      backgroundColor: theme.feltDark,
      appBar: AppBar(
        backgroundColor: theme.feltDark,
        foregroundColor: AppTokens.textPrimary,
        elevation: 0,
        title: const Text('Test Yourself', style: TextStyle(fontSize: 17)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heading('Drill the tricky spots'),
                const Text(
                  'Pick a theme and get an endless stream of hands, one decision at a time. '
                  'Choose the play you think is right, then see the answer and the reasoning. '
                  'The trickier the spot, the more often it comes up.',
                  style: _body,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final drill in _drillSets)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DrillTile(
                theme: theme,
                drill: drill,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => _DrillRunner(drill: drill)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DrillTile extends StatelessWidget {
  final AppearanceTheme theme;
  final _DrillSet drill;
  final VoidCallback onTap;
  const _DrillTile({required this.theme, required this.drill, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: withHaptic(onTap),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x18FFFFFF)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0x24FFFFFF),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(drill.icon, size: 20, color: AppTokens.textPrimary),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(drill.title,
                      style: const TextStyle(
                          color: AppTokens.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(drill.subtitle,
                      style: const TextStyle(color: AppTokens.textSecondary, fontSize: 12.5)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppTokens.textSecondary, size: 22),
          ],
        ),
      ),
    );
  }
}

/// Runs a drill as an endless stream: sample a hand, answer one decision, see
/// feedback, deal the next — forever. A running streak / accuracy is tracked.
/// Isolated from the real game: no deck, bankroll, or session stats are touched.
class _DrillRunner extends ConsumerStatefulWidget {
  final _DrillSet drill;
  const _DrillRunner({required this.drill});

  @override
  ConsumerState<_DrillRunner> createState() => _DrillRunnerState();
}

class _DrillRunnerState extends ConsumerState<_DrillRunner> {
  final _rng = Random();
  late DealScenario _cell;
  late _Hand _hand;
  Action? _answer;
  int _total = 0;
  int _correct = 0;
  int _streak = 0;
  int _best = 0;
  int _round = 0;

  RuleSet get _rs => ref.read(settingsProvider).ruleSet;

  @override
  void initState() {
    super.initState();
    _cell = _sample(widget.drill, _rs, _rng, null);
    _hand = _buildHand(_cell, _rng);
  }

  void _respond(Action a) {
    if (_answer != null) return;
    final optimal = getOptimalAction([_hand.p1, _hand.p2], _hand.dealer, _rs).action;
    final correct = a == optimal;
    setState(() {
      _answer = a;
      _total++;
      if (correct) {
        _correct++;
        _streak++;
        if (_streak > _best) _best = _streak;
      } else {
        _streak = 0;
      }
    });
    ref
        .read(drillStatsProvider.notifier)
        .record(drillId: widget.drill.id, wasCorrect: correct, streak: _streak);
    ref.read(achievementsProvider.notifier).evaluate();
  }

  void _next() {
    setState(() {
      _cell = _sample(widget.drill, _rs, _rng, _cell);
      _hand = _buildHand(_cell, _rng);
      _answer = null;
      _round++;
    });
  }

  void _reset() {
    setState(() {
      _total = 0;
      _correct = 0;
      _streak = 0;
      _best = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(appearanceProvider);
    final answered = _answer != null;
    final optimal = getOptimalAction([_hand.p1, _hand.p2], _hand.dealer, _rs);
    final actions = <Action>[
      Action.hit,
      Action.stand,
      Action.double,
      if (_hand.type == HandType.pair) Action.split,
      if (_rs.surrender != Surrender.none) Action.surrender,
    ];

    return Scaffold(
      backgroundColor: theme.feltDark,
      appBar: AppBar(
        backgroundColor: theme.feltDark,
        foregroundColor: AppTokens.textPrimary,
        elevation: 0,
        title: Text(widget.drill.title, style: const TextStyle(fontSize: 17)),
        actions: [
          if (_total > 0)
            IconButton(
              tooltip: 'Reset score',
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: withHaptic(_reset),
            ),
        ],
      ),
      body: Column(
        children: [
          _scoreBar(theme),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                AppearIn(
                  triggerKey: _round,
                  child: _ExampleHand([
                    ('Dealer shows', [_hand.dealer]),
                    ('You have', [_hand.p1, _hand.p2]),
                  ]),
                ),
                const SizedBox(height: 20),
                if (!answered)
                  const Center(
                    child: Text("What's the best play?",
                        style: TextStyle(
                            color: AppTokens.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final a in actions)
                      _choice(a, theme, answered: answered, optimal: optimal.action, chosen: _answer),
                  ],
                ),
                if (answered) ...[
                  const SizedBox(height: 20),
                  _feedback(theme, optimal),
                ],
              ],
            ),
          ),
          if (answered)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Row(
                children: [
                  const Spacer(),
                  GameButton(
                    label: 'Next hand',
                    theme: theme,
                    variant: GameBtn.gold,
                    onPressed: _next,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _scoreBar(AppearanceTheme theme) {
    final pct = _total > 0 ? (_correct / _total * 100).round() : 0;
    Widget stat(String label, String value, Color color) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppTokens.textSecondary,
                    fontSize: 10.5,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        );
    return Container(
      width: double.infinity,
      color: theme.feltDark,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          stat('STREAK', '$_streak', theme.goldLight),
          stat('BEST', '$_best', AppTokens.textPrimary),
          stat('ACCURACY', _total > 0 ? '$pct% ($_correct/$_total)' : '—',
              _total > 0 ? theme.goldLight : AppTokens.textSecondary),
        ],
      ),
    );
  }

  Widget _choice(Action a, AppearanceTheme theme,
      {required bool answered, required Action optimal, required Action? chosen}) {
    Color border;
    Color fg;
    Color bg = Colors.transparent;
    if (!answered) {
      border = theme.feltBorder;
      fg = AppTokens.textPrimary;
    } else if (a == optimal) {
      border = _feltGreen;
      fg = _lightGreen;
      bg = const Color(0x2227AE60);
    } else if (a == chosen) {
      border = _feltRed;
      fg = _lightRed;
      bg = const Color(0x22C0392B);
    } else {
      border = theme.feltBorder;
      fg = AppTokens.textSecondary;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: answered ? null : withHaptic(() => _respond(a)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 46,
        constraints: const BoxConstraints(minWidth: 88),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: border, width: 1.5),
        ),
        child: Text(_actionLabel(a),
            style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 15)),
      ),
    );
  }

  Widget _feedback(AppearanceTheme theme, OptimalAction optimal) {
    final correct = _answer == optimal.action;
    final accent = correct ? _lightGreen : _lightRed;
    return AppearIn(
      triggerKey: _round,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: (correct ? _feltGreen : _feltRed).withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: correct ? _feltGreen : _feltRed),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(correct ? Icons.check_circle : Icons.cancel, color: accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    correct
                        ? 'Correct — ${optimal.label.toLowerCase()}'
                        : 'Not quite — best play is ${optimal.label.toLowerCase()}',
                    style: TextStyle(color: accent, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(optimal.explanation, style: _body),
          ],
        ),
      ),
    );
  }
}
