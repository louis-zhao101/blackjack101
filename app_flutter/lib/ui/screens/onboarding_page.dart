import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/cards.dart' as bj;
import '../../services/sound_service.dart';
import '../../state/app_providers.dart';
import '../../state/appearance_provider.dart';
import '../theme/appearance.dart';
import '../widgets/blackjack_hand.dart';
import '../widgets/game_button.dart';

enum _Page { playHand, stats }

const _pages = [_Page.playHand, _Page.stats];

/// First-run onboarding: play a rigged winning hand, then see what gets tracked.
/// Cannot be skipped.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _controller = PageController();
  int _index = 0;

  // --- Page 1: the interactive hand ---
  final List<bj.Card> _player = [
    const bj.Card(rank: '10', suit: '♥'),
    const bj.Card(rank: '5', suit: '♣'),
  ];
  final List<bj.Card> _dealer = [
    const bj.Card(rank: '9', suit: '♣'),
    const bj.Card(rank: '10', suit: '♠', faceDown: true),
  ];
  bool _won = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  _Page get _page => _pages[_index];
  bool get _isLast => _index == _pages.length - 1;

  void _next() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  }

  void _complete() {
    if (!mounted) return;
    ref.read(onboardingSeenProvider.notifier).complete();
  }

  void _hit() {
    if (_player.length > 2) return; // one hit only
    SoundService.instance.cardDeal();
    setState(() => _player.add(const bj.Card(rank: '6', suit: '♦')));
    // Let the card land, then reveal the dealer's hole card and settle the win.
    Future.delayed(const Duration(milliseconds: 620), () {
      if (!mounted) return;
      SoundService.instance.blackjack();
      HapticFeedback.mediumImpact();
      setState(() {
        _dealer[1] = const bj.Card(rank: '10', suit: '♠');
        _won = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(appearanceProvider);
    return Scaffold(
      backgroundColor: theme.feltDark,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: theme.feltGradient),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Expanded(
                    child: PageView.builder(
                      controller: _controller,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (i) => setState(() => _index = i),
                      itemCount: _pages.length,
                      itemBuilder: (context, i) => _pageBody(_pages[i], theme),
                    ),
                  ),
                  _Dots(count: _pages.length, index: _index, theme: theme),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: _cta(theme),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageBody(_Page page, AppearanceTheme theme) => switch (page) {
    _Page.playHand => _PlayHandView(
      player: _player,
      dealer: _dealer,
      won: _won,
      theme: theme,
    ),
    _Page.stats => _StatsPreviewView(theme: theme),
  };

  Widget _cta(AppearanceTheme theme) {
    String label;
    VoidCallback onPressed;

    switch (_page) {
      case _Page.playHand:
        if (!_won) {
          label = 'Hit';
          onPressed = _hit;
        } else {
          label = 'Continue';
          onPressed = _next;
        }
      case _Page.stats:
        label = _isLast ? 'Get Started' : 'Next';
        onPressed = _isLast ? _complete : _next;
    }

    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: theme.gold,
        foregroundColor: theme.feltDark,
        disabledBackgroundColor: theme.gold.withValues(alpha: 0.5),
        disabledForegroundColor: theme.feltDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        ),
      ),
      onPressed: withHaptic(onPressed),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: Text(
          label,
          key: ValueKey(label),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// Page 1 — a curated hand the player wins by hitting to 21.
class _PlayHandView extends StatelessWidget {
  final List<bj.Card> player;
  final List<bj.Card> dealer;
  final bool won;
  final AppearanceTheme theme;
  const _PlayHandView({
    required this.player,
    required this.dealer,
    required this.won,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final cardWidth = w < 400 ? 52.0 : 62.0;
    final cardHeight = cardWidth * (100 / 72);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _label('DEALER'),
          const SizedBox(height: 6),
          // Reserve the dealer total's slot even before the win reveals it, so
          // showing the total doesn't grow the hand and push the rest down.
          // Height = hand vertical padding (16) + card + total row (~28).
          SizedBox(
            height: 16 + cardHeight + 28,
            child: Align(
              alignment: Alignment.topCenter,
              child: BlackjackHandView(
                cards: dealer,
                theme: theme,
                cardWidth: cardWidth,
                dealOffset: 1,
                showTotal: won,
              ),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 30,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: won
                  ? Text(
                      'Twenty-one — you win!',
                      key: const ValueKey('win'),
                      style: TextStyle(
                        color: theme.goldLight,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : const Text(
                      'You have 15. Your move — tap Hit.',
                      key: ValueKey('prompt'),
                      style: TextStyle(
                        color: AppTokens.textSecondary,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 22),
          BlackjackHandView(cards: player, theme: theme, cardWidth: cardWidth),
          const SizedBox(height: 6),
          _label('YOU'),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      color: AppTokens.textSecondary,
      fontSize: 12,
      letterSpacing: 1.5,
    ),
  );
}

/// Page 2 — a taste of what the app tracks.
class _StatsPreviewView extends StatelessWidget {
  final AppearanceTheme theme;
  const _StatsPreviewView({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Track every decision',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTokens.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0x14FFFFFF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0x18FFFFFF)),
            ),
            child: Column(
              children: [
                const Text(
                  '87%',
                  style: TextStyle(
                    color: Color(0xFF6EE7B7),
                    fontSize: 52,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text(
                  'STRATEGY ACCURACY',
                  style: TextStyle(
                    color: AppTokens.textSecondary,
                    fontSize: 11,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final h in const [
                      12.0,
                      16.0,
                      13.0,
                      20.0,
                      24.0,
                      22.0,
                      30.0,
                    ])
                      Container(
                        width: 9,
                        height: h,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: theme.gold.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'last 7 sessions',
                  style: TextStyle(
                    color: AppTokens.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Every play is graded against basic strategy. Watch your accuracy '
            'climb, session over session — and earn badges as you go.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTokens.textSecondary,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int index;
  final AppearanceTheme theme;
  const _Dots({required this.count, required this.index, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == index ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == index
                  ? theme.gold
                  : AppTokens.textSecondary.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
