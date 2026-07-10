import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../engine/cards.dart' as bj;
import '../../state/app_providers.dart';
import '../../state/appearance_provider.dart';
import '../theme/appearance.dart';
import '../widgets/playing_card.dart';

/// Marketing landing page shown as the first screen on the hosted web build. A
/// visitor lands here rather than dropping straight into the game; tapping
/// "Play in your browser" enters the app (and is remembered, so returning
/// visitors skip it). Never shown on mobile — the store listing is the funnel
/// there. Styled with the active felt/gold appearance so it reads as one product
/// with the app behind it.
class WebLandingPage extends ConsumerWidget {
  const WebLandingPage({super.key});

  // TODO: replace with the real listings once the apps are published.
  static const _appStoreUrl = 'https://apps.apple.com/app/idYOUR_APP_ID';
  static const _playStoreUrl =
      'https://play.google.com/store/apps/details?id=YOUR_PACKAGE_NAME';

  static const _features = [
    (
      '♠',
      'Learn the optimal play',
      'The mathematically correct move for every hand the table deals you.',
    ),
    (
      '💡',
      'Instant feedback',
      'See what was optimal and why after every decision, then drill your weak spots.',
    ),
    (
      '📈',
      'Track your progress',
      'Accuracy trends, streaks, a strategy heatmap, and achievements as you improve.',
    ),
    (
      '🎯',
      'Play money only',
      'A pure trainer — no real-money gambling, no wagering, no cash prizes.',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appearanceProvider);
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: theme.feltGradient),
        child: Stack(
          children: [
            Positioned.fill(child: IgnorePointer(child: _DecoCards(theme: theme))),
            SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 720;
              return SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: wide ? 32 : 20, vertical: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _header(context, theme),
                          SizedBox(height: wide ? 64 : 40),
                          _hero(context, ref, theme, wide),
                          SizedBox(height: wide ? 56 : 40),
                          _featureGrid(theme, wide),
                          const SizedBox(height: 48),
                          _footer(context, theme),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, AppearanceTheme theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('♠ Blackjack 101 ♥',
            style: TextStyle(
                color: theme.gold, fontSize: 20, fontWeight: FontWeight.w700)),
        TextButton(
          onPressed: () => openPrivacyPolicy(),
          style: TextButton.styleFrom(foregroundColor: AppTokens.textSecondary),
          child: const Text('Privacy'),
        ),
      ],
    );
  }

  Widget _hero(
      BuildContext context, WidgetRef ref, AppearanceTheme theme, bool wide) {
    return Column(
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(
              color: AppTokens.textPrimary,
              fontSize: wide ? 52 : 36,
              fontWeight: FontWeight.w800,
              height: 1.1,
              letterSpacing: -0.5,
            ),
            children: [
              const TextSpan(text: 'Master blackjack '),
              TextSpan(text: 'strategy.', style: TextStyle(color: theme.goldLight)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Text(
            'Play real hands, get every decision graded against basic strategy, '
            'and watch your accuracy climb — session after session.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppTokens.textSecondary,
                fontSize: wide ? 20 : 16,
                height: 1.5),
          ),
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () => ref.read(landingSeenProvider.notifier).enter(),
          style: FilledButton.styleFrom(
            backgroundColor: theme.gold,
            foregroundColor: theme.feltDark,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          child: const Text('Play in your browser'),
        ),
        const SizedBox(height: 24),
        Text('Or get the app',
            style: TextStyle(
                color: AppTokens.textSecondary,
                fontSize: 13,
                letterSpacing: 0.3)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            _StoreBadge(
              icon: const Icon(Icons.apple, color: Colors.white, size: 26),
              top: 'Download on the',
              bottom: 'App Store',
              onTap: () => _open(_appStoreUrl),
            ),
            _StoreBadge(
              icon: const _PlayTriangle(),
              top: 'GET IT ON',
              bottom: 'Google Play',
              onTap: () => _open(_playStoreUrl),
            ),
          ],
        ),
      ],
    );
  }

  Widget _featureGrid(AppearanceTheme theme, bool wide) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: wide ? 2 : 1,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        mainAxisExtent: wide ? 210 : 168,
      ),
      children: [
        for (final (icon, title, body) in _features)
          _FeatureCard(icon: icon, title: title, body: body, theme: theme),
      ],
    );
  }

  Widget _footer(BuildContext context, AppearanceTheme theme) {
    return Column(
      children: [
        Divider(color: theme.feltBorder, height: 1),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            const Text('© Blackjack 101',
                style:
                    TextStyle(color: AppTokens.textSecondary, fontSize: 13)),
            Wrap(
              spacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(
                  onPressed: () => openPrivacyPolicy(),
                  style: TextButton.styleFrom(foregroundColor: theme.gold),
                  child: const Text('Privacy Policy'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // Resolve against the current page origin so a path like "/privacy.html"
  // becomes an absolute URL — url_launcher's web backend won't open a
  // scheme-less URI. Same tab for our own pages, a new tab for the stores.
  Future<void> _open(String url, {String window = '_blank'}) async {
    await launchUrl(Uri.base.resolve(url), webOnlyWindowName: window);
  }
}

class _FeatureCard extends StatelessWidget {
  final String icon;
  final String title;
  final String body;
  final AppearanceTheme theme;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                  color: AppTokens.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(body,
              style: const TextStyle(
                  color: AppTokens.textSecondary, fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}

/// A store-badge-style button (black pill, brand mark + two-line label). A
/// stand-in for the official App Store / Google Play badge art, which should
/// replace these before launch to meet each store's branding guidelines.
class _StoreBadge extends StatelessWidget {
  final Widget icon;
  final String top;
  final String bottom;
  final VoidCallback onTap;

  const _StoreBadge({
    required this.icon,
    required this.top,
    required this.bottom,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 26, height: 26, child: Center(child: icon)),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(top,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 10, height: 1.1)),
                  Text(bottom,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          height: 1.15,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Faded playing cards scattered around the edges as background decoration.
/// Non-interactive (wrapped in [IgnorePointer] by the caller) and sized to the
/// viewport, so they sit behind the content and bleed off the edges. Positions
/// are fractions of the available space so they adapt to any window size.
class _DecoCards extends StatelessWidget {
  final AppearanceTheme theme;
  const _DecoCards({required this.theme});

  // (rank, suit, left%, top%, angle, width) — negative/over-1 fractions push
  // the card partly off the corresponding edge.
  static const _cards = [
    ('A', '♠', -0.04, -0.06, -0.28, 150.0),
    ('K', '♥', 0.82, 0.04, 0.32, 168.0),
    ('Q', '♦', -0.06, 0.52, 0.20, 140.0),
    ('J', '♣', 0.86, 0.62, -0.24, 158.0),
    ('10', '♥', 0.30, 0.90, 0.16, 128.0),
    ('A', '♦', 0.55, -0.10, 0.10, 120.0),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth, h = c.maxHeight;
        return Stack(
          children: [
            for (final (rank, suit, fx, fy, angle, cw) in _cards)
              Positioned(
                left: fx * w,
                top: fy * h,
                child: Opacity(
                  opacity: 0.12,
                  child: Transform.rotate(
                    angle: angle,
                    child: PlayingCardView(
                      card: bj.Card(rank: rank, suit: suit),
                      theme: theme,
                      width: cw,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The Google Play "play" mark — a right-pointing triangle with the store's
/// signature multi-color vertical gradient.
class _PlayTriangle extends StatelessWidget {
  const _PlayTriangle();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(18, 20), painter: _PlayTrianglePainter());
}

class _PlayTrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF00C3FF),
          Color(0xFF00E676),
          Color(0xFFFFD600),
          Color(0xFFFF3D00),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
