import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/cards.dart' as bj;
import '../../state/app_providers.dart';
import '../../state/appearance_provider.dart';
import '../widgets/playing_card.dart';

/// Launch splash: a black screen that deals a small two-card hand, then flies it
/// back off — each cycle a full deal-in followed by its exact reverse (the same
/// 26px slide + fade the table uses, played backwards). Loops until the app is
/// ready, with a minimum number of cycles so a fast load isn't jarring.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  // Per-card entrance mirrors the table deal exactly (see _DealtCard); the exit
  // is that same slide + fade, mirrored in time but continuing down toward the
  // bottom edge by [_slide].
  static const double _enterMs = 200;
  static const double _enterStaggerMs = 150;
  static const double _holdMs = 450;
  static const double _exitMs = 200;
  static const double _exitStaggerMs = 150;
  static const double _endGapMs = 400; // empty beat between cycles
  static const double _slide = 26; // matches the table's deal offset
  static const int _minCycles = 2;

  static const _back = bj.Card(rank: 'A', suit: '♠', faceDown: true);
  static const _ranks = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A'];
  static const _suits = ['♠', '♥', '♦', '♣'];

  final Random _rng = Random();
  // A fresh face-up card each cycle; the second card is always the deck back.
  bj.Card _faceUp = const bj.Card(rank: 'A', suit: '♠');
  List<bj.Card> get _cards => [_faceUp, _back];

  bj.Card _randomCard() => bj.Card(
        rank: _ranks[_rng.nextInt(_ranks.length)],
        suit: _suits[_rng.nextInt(_suits.length)],
      );

  int _cyclesDone = 0;
  late final AnimationController _c =
      AnimationController(vsync: this, duration: Duration(milliseconds: _cycleMs.round()));

  double get _cycleMs {
    final n = _cards.length;
    final lastEnterEnd = (n - 1) * _enterStaggerMs + _enterMs;
    // Tail after the last card exits — all cards are gone, so it reads as a
    // pause before the next deal.
    return lastEnterEnd + _holdMs + (n - 1) * _exitStaggerMs + _exitMs + _endGapMs;
  }

  @override
  void initState() {
    super.initState();
    _runCycle();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _runCycle() {
    // Swap in a new face card while the cards are invisible (value 0), so the
    // change is never seen mid-animation.
    _faceUp = _randomCard();
    _c.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      _cyclesDone++;
      if (ref.read(appReadyProvider) && _cyclesDone >= _minCycles) {
        // Cards have already flown off — dismiss into the app.
        ref.read(splashDoneProvider.notifier).markDone();
      } else {
        _runCycle();
      }
    });
  }

  /// Opacity + vertical offset for card [i] at time [ms] into the cycle.
  ({double opacity, double dy}) _cardState(int i, double ms) {
    final n = _cards.length;
    final enterStart = i * _enterStaggerMs;
    final enterEnd = enterStart + _enterMs;
    final lastEnterEnd = (n - 1) * _enterStaggerMs + _enterMs;
    final exitBase = lastEnterEnd + _holdMs;
    // Exit in reverse order (last dealt leaves first) so it's the exact opposite.
    final exitStart = exitBase + (n - 1 - i) * _exitStaggerMs;
    final exitEnd = exitStart + _exitMs;

    if (ms < enterStart) return (opacity: 0, dy: -_slide);
    if (ms < enterEnd) {
      final t = Curves.easeOutCubic.transform(((ms - enterStart) / _enterMs).clamp(0.0, 1.0));
      return (opacity: t, dy: (1 - t) * -_slide);
    }
    if (ms < exitStart) return (opacity: 1, dy: 0);
    if (ms < exitEnd) {
      // Leave toward the bottom edge: same slide + fade as the deal-in, mirrored
      // in time but continuing downward rather than retreating up.
      final p = Curves.easeInCubic.transform(((ms - exitStart) / _exitMs).clamp(0.0, 1.0));
      return (opacity: 1 - p, dy: p * _slide);
    }
    return (opacity: 0, dy: _slide);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(appearanceProvider);
    final w = MediaQuery.of(context).size.width;
    // Match the table's card size so it looks identical to in-game dealing.
    final cardWidth = w < 480
        ? 58.0
        : w < 900
            ? 76.0
            : 88.0;
    final overlap = cardWidth * 0.17;
    final cardHeight = cardWidth * (100 / 72);
    final stackWidth = cardWidth + (_cards.length - 1) * (cardWidth - overlap);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final ms = _c.value * _cycleMs;
            return SizedBox(
              width: stackWidth,
              height: cardHeight,
              child: Stack(
                children: [
                  for (var i = 0; i < _cards.length; i++)
                    Builder(builder: (_) {
                      final s = _cardState(i, ms);
                      return Positioned(
                        left: i * (cardWidth - overlap),
                        child: Opacity(
                          opacity: s.opacity.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(0, s.dy),
                            // A crisp hairline traces the card edge so dark
                            // decks (Greek, Tarot…) still read against the black
                            // splash — no glow. Foreground so it sits on the art.
                            child: DecoratedBox(
                              position: DecorationPosition.foreground,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(cardWidth * 0.06),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  width: 1,
                                ),
                              ),
                              child: PlayingCardView(
                                  card: _cards[i], theme: theme, width: cardWidth),
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
