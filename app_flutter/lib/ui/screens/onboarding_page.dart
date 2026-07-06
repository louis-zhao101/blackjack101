import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';

import '../../state/app_providers.dart';
import '../../state/appearance_provider.dart';
import '../theme/appearance.dart';
import '../widgets/game_button.dart';

class _Slide {
  final IconData icon;
  final String title;
  final String body;
  const _Slide({required this.icon, required this.title, required this.body});
}

const _introSlides = <_Slide>[
  _Slide(
    icon: Icons.style_outlined,
    title: 'Play smarter blackjack',
    body:
        'Deal real hands and learn the mathematically optimal move for every '
        'card the table throws at you.',
  ),
  _Slide(
    icon: Icons.lightbulb_outline,
    title: 'Instant strategy feedback',
    body:
        'Every decision is checked against basic strategy — see what was '
        'optimal, understand why, then drill the spots you miss.',
  ),
  _Slide(
    icon: Icons.trending_up,
    title: 'Watch yourself improve',
    body:
        'Track your accuracy, streaks, and weak hands over time as your game '
        'sharpens session after session.',
  ),
];

const _reviewSlide = _Slide(
  icon: Icons.favorite,
  title: "We're a small team",
  body:
      'Blackjack 101 is built by a tiny group of developers. If it helps your '
      'game, a quick review would mean the world — and helps others find us.',
);

// The review ask is store-only; the web build ends on the last intro slide.
const _slides = kIsWeb ? _introSlides : [..._introSlides, _reviewSlide];

/// First-run onboarding: three intro slides, then a heartfelt ask to rate the
/// app. Cannot be skipped — the final page always leads into the game.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _controller = PageController();
  int _index = 0;

  // Review-page gate: the user taps "Leave a review", the OS prompt appears,
  // and a few seconds later the "I've left a review" button unlocks so they can
  // proceed. There is no other way forward from the final page.
  static const _proceedDelay = Duration(seconds: 4);
  bool _reviewTapped = false;
  bool _canProceed = false;
  Timer? _proceedTimer;

  @override
  void dispose() {
    _proceedTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  bool get _isLastPage => _index == _slides.length - 1;

  /// The final page is the review ask everywhere except web, which has no store
  /// review flow and simply ends on the last intro slide.
  bool get _isReviewPage => !kIsWeb && _isLastPage;

  void _next() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  }

  void _leaveReview() {
    setState(() => _reviewTapped = true);
    _requestReview();
    _proceedTimer = Timer(_proceedDelay, () {
      if (mounted) setState(() => _canProceed = true);
    });
  }

  Future<void> _requestReview() async {
    // The OS decides whether to actually surface the prompt (and rate-limits
    // it), so this is a no-op when unavailable.
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) {
        await review.requestReview();
      }
    } catch (_) {}
  }

  void _complete() {
    if (!mounted) return;
    ref.read(onboardingSeenProvider.notifier).complete();
  }

  Widget _buildCta(AppearanceTheme theme) {
    final String label;
    final VoidCallback? onPressed;
    Widget? leading;
    if (!_isLastPage) {
      label = 'Next';
      onPressed = _next;
    } else if (!_isReviewPage) {
      // Web: last intro slide leads straight into the app.
      label = 'Get Started';
      onPressed = _complete;
    } else if (!_reviewTapped) {
      label = 'Leave a review';
      onPressed = _leaveReview;
    } else if (_canProceed) {
      label = "I've left a review";
      onPressed = _complete;
    } else {
      // Prompt fired; briefly hold the user here until they can proceed.
      label = 'Thanks for the support';
      onPressed = null;
      leading = SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: theme.feltDark),
      );
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
        child: Row(
          key: ValueKey(label),
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading, const SizedBox(width: 10)],
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
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
                  onPageChanged: (i) => setState(() => _index = i),
                  itemCount: _slides.length,
                  itemBuilder: (context, i) => _SlideView(slide: _slides[i], theme: theme),
                ),
              ),
              _Dots(count: _slides.length, index: _index, theme: theme),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: _buildCta(theme),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  final _Slide slide;
  final AppearanceTheme theme;
  const _SlideView({required this.slide, required this.theme});

  @override
  Widget build(BuildContext context) {
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
            child: Icon(slide.icon, size: 60, color: theme.goldLight),
          ),
          const SizedBox(height: 40),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTokens.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            slide.body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTokens.textSecondary,
              fontSize: 16,
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
              color: i == index ? theme.gold : AppTokens.textSecondary.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
