import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';

import '../../engine/cards.dart' as bj;
import '../../services/sound_service.dart';
import '../../state/app_providers.dart';
import '../../state/appearance_provider.dart';
import '../theme/appearance.dart';
import '../widgets/blackjack_hand.dart';
import '../widgets/game_button.dart';

enum _Page { playHand, stats, review }

// The review ask is store-only; the web build ends on the stats page.
const _pages = kIsWeb
    ? [_Page.playHand, _Page.stats]
    : [_Page.playHand, _Page.stats, _Page.review];

/// First-run onboarding: play a rigged winning hand, see what gets tracked, then
/// (on store builds) a heartfelt ask to rate the app. Cannot be skipped.
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

  // --- Review page gate (store builds only) ---
  static const _proceedDelay = Duration(seconds: 2);
  bool _reviewTapped = false;
  bool _canProceed = false;
  Timer? _proceedTimer;

  @override
  void dispose() {
    _proceedTimer?.cancel();
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

  void _leaveReview() {
    setState(() => _reviewTapped = true);
    _requestReview();
    _proceedTimer = Timer(_proceedDelay, () {
      if (mounted) setState(() => _canProceed = true);
    });
  }

  Future<void> _requestReview() async {
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) await review.requestReview();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(appearanceProvider);
    return Scaffold(
      backgroundColor: theme.feltDark,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: theme.feltGradient),
        child: SafeArea(
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
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                child: SizedBox(width: double.infinity, height: 52, child: _cta(theme)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pageBody(_Page page, AppearanceTheme theme) => switch (page) {
        _Page.playHand => _PlayHandView(
            player: _player, dealer: _dealer, won: _won, theme: theme),
        _Page.stats => _StatsPreviewView(theme: theme),
        _Page.review => const _ReviewView(),
      };

  Widget _cta(AppearanceTheme theme) {
    String label;
    VoidCallback? onPressed;
    Widget? leading;

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
      case _Page.review:
        if (!_reviewTapped) {
          label = 'Leave a review';
          onPressed = _leaveReview;
        } else if (_canProceed) {
          label = "I've left a review";
          onPressed = _complete;
        } else {
          label = 'Thanks for the support';
          onPressed = null;
          leading = SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: theme.feltDark),
          );
        }
    }

    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: theme.gold,
        foregroundColor: theme.feltDark,
        disabledBackgroundColor: theme.gold.withValues(alpha: 0.5),
        disabledForegroundColor: theme.feltDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusLg)),
      ),
      onPressed: onPressed == null ? null : withHaptic(onPressed),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: Row(
          key: ValueKey(label),
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading, const SizedBox(width: 10)],
            Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
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
  const _PlayHandView(
      {required this.player, required this.dealer, required this.won, required this.theme});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final cardWidth = w < 400 ? 52.0 : 62.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _label('DEALER'),
          const SizedBox(height: 6),
          BlackjackHandView(
            cards: dealer,
            theme: theme,
            cardWidth: cardWidth,
            dealOffset: 1,
            showTotal: won,
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 30,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: won
                  ? Text('Twenty-one — you win!',
                      key: const ValueKey('win'),
                      style: TextStyle(
                          color: theme.goldLight, fontSize: 20, fontWeight: FontWeight.bold))
                  : const Text('You have 15. Your move — tap Hit.',
                      key: ValueKey('prompt'),
                      style: TextStyle(color: AppTokens.textSecondary, fontSize: 14)),
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

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          color: AppTokens.textSecondary, fontSize: 12, letterSpacing: 1.5));
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
          const Text('Track every decision',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppTokens.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.15)),
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
                const Text('87%',
                    style: TextStyle(
                        color: Color(0xFF6EE7B7), fontSize: 52, fontWeight: FontWeight.w800)),
                const Text('STRATEGY ACCURACY',
                    style: TextStyle(
                        color: AppTokens.textSecondary, fontSize: 11, letterSpacing: 2)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final h in const [12.0, 16.0, 13.0, 20.0, 24.0, 22.0, 30.0])
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
                const Text('last 7 sessions',
                    style: TextStyle(color: AppTokens.textSecondary, fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Every play is graded against basic strategy. Watch your accuracy '
            'climb, session over session — and earn badges as you go.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTokens.textSecondary, fontSize: 15, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// Page 3 — the review ask (store builds only).
class _ReviewView extends ConsumerWidget {
  const _ReviewView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appearanceProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 128,
            height: 128,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.gold.withValues(alpha: 0.14),
              border: Border.all(color: theme.gold.withValues(alpha: 0.5), width: 1.5),
            ),
            child: Icon(Icons.favorite, size: 60, color: theme.goldLight),
          ),
          const SizedBox(height: 40),
          const Text("We're a small team",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppTokens.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.15)),
          const SizedBox(height: 16),
          const Text(
            'Blackjack 101 is built by a tiny group of developers. If it helps '
            'your game, a quick review would mean the world — and helps others '
            'find us.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTokens.textSecondary, fontSize: 16, height: 1.5),
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
              color: i == index ? theme.gold : AppTokens.textSecondary.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
