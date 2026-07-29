import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/cards.dart' as bj;
import '../../engine/engine.dart' as eng;
import '../../services/sound_service.dart';
import '../../state/app_providers.dart';
import '../../state/appearance_provider.dart';
import '../../state/game_provider.dart';
import '../../state/stats_provider.dart';
import '../../state/store_provider.dart';
import '../theme/appearance.dart';
import '../widgets/blackjack_hand.dart';
import '../widgets/game_button.dart';
import '../widgets/playing_card.dart';
import 'shop_page.dart';

int _visibleCards(eng.GameState g) =>
    g.dealerCards.length + g.playerHands.fold<int>(0, (s, h) => s + h.cards.length);

/// Net hand result across (possibly split) hands: +1 per win/blackjack, −1 per
/// loss/surrender, 0 per push. Drives the outcome jingle and headline color.
int _handScore(List<eng.PlayerHand> hands) {
  var score = 0;
  for (final h in hands) {
    switch (h.result) {
      case eng.HandResult.win:
      case eng.HandResult.blackjack:
        score++;
      case eng.HandResult.lose:
      case eng.HandResult.surrender:
        score--;
      case eng.HandResult.push:
      case null:
        break;
    }
  }
  return score;
}

void _reactToGameChange(GameStoreState? prev, GameStoreState next) {
  final sound = SoundService.instance;
  final ng = next.game;
  final pg = prev?.game;

  // A larger deck than the previous state means the shoe was reshuffled.
  if (pg != null && ng.deck.length > pg.deck.length) sound.shuffle();

  // A fresh deal (new roundId) always lays down 4 cards — even one that lands
  // straight on complete, e.g. a dealt / "Deal Again" blackjack.
  final freshDeal =
      next.roundId != prev?.roundId && ng.phase != eng.GamePhase.betting;

  // Fling one card off the deck for every card the engine just drew: a fresh
  // deal is 4 (player, dealer, player, dealer); otherwise it's however many
  // cards appeared — 1 for a hit/double, N for the dealer drawing out.
  final int drawn;
  if (freshDeal) {
    drawn = 4;
  } else if (pg != null) {
    drawn = (_visibleCards(ng) - _visibleCards(pg)).clamp(0, 12);
  } else {
    drawn = 0;
  }
  if (drawn > 0) _flourishKey.currentState?.fly(drawn);

  // Card-deal clicks for player-facing cards, staggered by 160ms. The opening
  // deal (4) waits kDealLeadMs so it stays in sync with the flourish; hits and
  // splits fire immediately. Decoupled from the resolution branch below so a
  // dealt blackjack (which skips playerTurn) still clicks.
  final int dealt;
  if (freshDeal) {
    dealt = 4;
  } else if (ng.phase == eng.GamePhase.playerTurn &&
      pg?.phase == eng.GamePhase.playerTurn) {
    dealt = (_visibleCards(ng) - _visibleCards(pg!)).clamp(0, 12);
  } else {
    dealt = 0;
  }
  final lead = freshDeal ? kDealLeadMs : 0;
  for (var i = 0; i < dealt; i++) {
    final delay = lead + i * 160;
    if (delay <= 0) {
      sound.cardDeal();
    } else {
      Future.delayed(Duration(milliseconds: delay), sound.cardDeal);
    }
  }

  // Outcome jingle when a hand resolves: either the phase just turned complete,
  // or a fresh deal landed straight on complete (a "Deal Again" blackjack goes
  // complete -> complete). Reflects the result, matching the headline —
  // blackjack, then win / loss / push (tallied across split hands).
  final resolved = ng.phase == eng.GamePhase.complete &&
      (pg?.phase != eng.GamePhase.complete || next.roundId != prev?.roundId);
  if (resolved) {
    final hands = ng.playerHands;
    final score = _handScore(hands);
    final void Function() jingle;
    if (hands.any((h) => h.result == eng.HandResult.blackjack)) {
      jingle = sound.blackjack;
    } else if (score > 0) {
      jingle = sound.win;
    } else if (score < 0) {
      jingle = sound.lose;
    } else {
      jingle = sound.push;
    }
    // On an instant (dealt) blackjack — player's or dealer's — wait for the
    // cards and the hole-card reveal to land before the win/lose music, so the
    // outcome reads clearly instead of the sound preceding it.
    if (freshDeal) {
      Future.delayed(const Duration(milliseconds: 1200), jingle);
    } else {
      jingle();
    }
  }
}

void _confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required VoidCallback onConfirm,
}) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: withHaptic(() => Navigator.pop(context)),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: withHaptic(() {
            Navigator.pop(context);
            onConfirm();
          }),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}

class PlayPage extends ConsumerWidget {
  const PlayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<GameStoreState>(gameProvider, _reactToGameChange);
    final theme = ref.watch(appearanceProvider);
    final store = ref.watch(gameProvider);
    final game = store.game;

    return Column(
      children: [
        _StatsBar(store: store, theme: theme),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth < 480
                  ? 58.0
                  : constraints.maxWidth < 900
                  ? 76.0
                  : 88.0;
              // On wide desktop windows the felt stays full-bleed, but the
              // corner deck hugs a centred band (matching the list pages' cap)
              // instead of the far screen edges.
              const bandWidth = 900.0;
              final contentWidth = constraints.maxWidth - 32;
              final sideInset = math.max(0.0, (contentWidth - bandWidth) / 2);
              final band = contentWidth - 2 * sideInset;
              // The dealer row is centre-aligned, so each extra card widens it
              // symmetrically and its left edge creeps toward the corner deck.
              // Once it would overlap, tuck the (decorative) deck off-screen.
              final overlap = cardWidth * 0.17;
              final dealerCount = game.dealerCards.length;
              final dealerHandWidth = dealerCount == 0
                  ? 0.0
                  : cardWidth + (dealerCount - 1) * (cardWidth - overlap);
              final dealerHandLeft = (band - dealerHandWidth) / 2;
              final tuckDeck =
                  dealerCount > 0 && dealerHandLeft < cardWidth;
              return Container(
                width: double.infinity,
                decoration: BoxDecoration(gradient: theme.feltGradient),
                clipBehavior: Clip.hardEdge,
                padding: const EdgeInsets.all(16),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: sideInset - cardWidth * 0.35,
                      top: 2,
                      child: AnimatedSlide(
                        offset: tuckDeck ? const Offset(-0.85, 0) : Offset.zero,
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeInOut,
                        child: AnimatedOpacity(
                          opacity: tuckDeck ? 0 : 1,
                          duration: const Duration(milliseconds: 320),
                          child: Transform.rotate(
                            angle: -0.25,
                            child: _DeckStack(theme: theme, width: cardWidth),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: sideInset - cardWidth * 0.35,
                      top: 2,
                      child: _DealFlourish(
                        key: _flourishKey,
                        theme: theme,
                        width: cardWidth,
                      ),
                    ),
                    Column(
                      children: [
                        _DealerZone(
                          game: game,
                          theme: theme,
                          cardWidth: cardWidth,
                          roundId: store.roundId,
                        ),
                        Expanded(
                          child: Center(
                            child: _TableCenter(
                                game: game, theme: theme, hasDealt: store.hasDealtInSession),
                          ),
                        ),
                        _PlayerZone(
                          game: game,
                          theme: theme,
                          cardWidth: cardWidth,
                          roundId: store.roundId,
                        ),
                        SizedBox(
                          height: 28,
                          width: double.infinity,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child:
                                (store.lastHandInfo != null &&
                                    game.phase != eng.GamePhase.betting)
                                ? AppearIn(
                                    triggerKey: store.lastHandInfo,
                                    child: _StrategyHint(
                                      info: store.lastHandInfo!,
                                      theme: theme,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        _Controls(store: store, theme: theme),
      ],
    );
  }
}

class _StatsBar extends ConsumerWidget {
  final GameStoreState store;
  final AppearanceTheme theme;
  const _StatsBar({required this.store, required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Accuracy mirrors the current session the Stats page shows — per-hand and
    // persisted — so the two views can never disagree (a fresh in-memory counter
    // would reset on relaunch while the session lives on).
    final hands = ref.watch(statsProvider).currentSession?.hands ?? const [];
    final total = hands.length;
    final correct = hands.where((h) => h.wasCorrect).length;
    final hasPlays = total > 0;
    final pct = hasPlays ? (correct / total * 100).round() : 0;
    final pctColor = pct >= 80
        ? const Color(0xFF6EE7B7)
        : pct >= 60
        ? theme.goldLight
        : const Color(0xFFFC8181);

    return Container(
      width: double.infinity,
      color: theme.feltDark,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: withHaptic(() => ref.read(navTabProvider.notifier).select(2)),
        child: _item(
          'SESSION ACCURACY',
          hasPlays ? '$pct% ($correct/$total)' : '—',
          hasPlays ? pctColor : AppTokens.textSecondary,
        ),
      ),
    );
  }

  Widget _item(String label, String value, Color color) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: AppTokens.textSecondary,
          fontSize: 10.5,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 3),
      SizedBox(
        height: 28,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    ],
  );
}

class _DealerZone extends StatelessWidget {
  final eng.GameState game;
  final AppearanceTheme theme;
  final double cardWidth;
  final int roundId;
  const _DealerZone({
    required this.game,
    required this.theme,
    required this.cardWidth,
    required this.roundId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'DEALER',
          style: TextStyle(
            color: AppTokens.textSecondary,
            fontSize: 12,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        if (game.dealerCards.isNotEmpty)
          BlackjackHandView(
            cards: game.dealerCards,
            theme: theme,
            cardWidth: cardWidth,
            dealOffset: 1,
            roundId: roundId,
          ),
      ],
    );
  }
}

/// Decorative shoe/deck in the corner of the table — a few offset card-paper
/// edges behind a face-down card showing the player's chosen back. Tapping it
/// fans the top card out with a card-slide sound, for a bit of fidget delight.
class _DeckStack extends StatefulWidget {
  final AppearanceTheme theme;
  final double width;
  const _DeckStack({required this.theme, required this.width});

  @override
  State<_DeckStack> createState() => _DeckStackState();
}

class _DeckStackState extends State<_DeckStack> with SingleTickerProviderStateMixin {
  static const _layers = 9;
  static const _step = 1.3;
  // A touch of leftward drift per layer so the pile reads correctly against the
  // deck's rotation.
  static const _stepX = 0.4;

  late final AnimationController _fan =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  void _tap() {
    lightHaptic();
    SoundService.instance.cardSlide();
    _fan.forward(from: 0);
  }

  @override
  void dispose() {
    _fan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.width;
    final theme = widget.theme;
    final height = width * (100 / 72);
    final radius = BorderRadius.circular(width * 0.06);
    return GestureDetector(
      onTap: _tap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width,
        height: height + _layers * _step,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = _layers; i >= 1; i--)
              Positioned(
                left: -i * _stepX,
                top: i * _step,
                child: Container(
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    color: theme.cardFace,
                    borderRadius: radius,
                    border: Border.all(color: const Color(0x33000000)),
                  ),
                ),
              ),
            // The next card down, so fanning the top card reveals a real back.
            Positioned(
              left: -_stepX,
              top: _step,
              child: PlayingCardView(
                card: const bj.Card(rank: 'A', suit: '♠', faceDown: true),
                theme: theme,
                width: width,
                showShadow: false,
              ),
            ),
            AnimatedBuilder(
              animation: _fan,
              child: PlayingCardView(
                card: const bj.Card(rank: 'A', suit: '♠', faceDown: true),
                theme: theme,
                width: width,
                showShadow: false,
              ),
              builder: (context, child) {
                // Top card slides out and rotates a touch, then settles back.
                final wave = math.sin(_fan.value * math.pi);
                return Transform.translate(
                  offset: Offset(wave * width * 0.16, wave * -width * 0.05),
                  child: Transform.rotate(
                    angle: wave * 0.18,
                    alignment: Alignment.bottomCenter,
                    child: child,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Drives the deal flourish — one card back flung off the top of the deck, off
/// screen to the left, for every card the engine draws (see [_reactToGameChange]).
final GlobalKey<_DealFlourishState> _flourishKey = GlobalKey<_DealFlourishState>();

class _DealFlourish extends StatefulWidget {
  final AppearanceTheme theme;
  final double width;
  const _DealFlourish({super.key, required this.theme, required this.width});

  @override
  State<_DealFlourish> createState() => _DealFlourishState();
}

class _DealFlourishState extends State<_DealFlourish> with TickerProviderStateMixin {
  final List<AnimationController> _active = [];

  /// Flings [count] card backs off the deck, staggered so they trail each other.
  void fly(int count) {
    for (var i = 0; i < count; i++) {
      final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 360));
      _active.add(c);
      c.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _active.remove(c);
          c.dispose();
          if (mounted) setState(() {});
        }
      });
      Future.delayed(Duration(milliseconds: i * 70), () {
        if (mounted && _active.contains(c)) c.forward();
      });
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in _active) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Cap the fly-off distance so it's a short flourish that fades out in place,
    // not a card streaking the full width of a wide (desktop web) window.
    final travel = MediaQuery.of(context).size.width.clamp(0.0, 340.0);
    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Paint newest-first so the earliest-launched (first to fly) card sits
          // on top — the top of the deck always leaves first.
          for (final c in _active.reversed)
            AnimatedBuilder(
              animation: c,
              builder: (context, _) {
                final e = Curves.easeIn.transform(c.value);
                return Transform.translate(
                  offset: Offset(-e * travel, -e * widget.width * 0.25),
                  child: Transform.rotate(
                    angle: -0.25 - e * 0.6,
                    child: Opacity(
                      // Stay fully visible through most of the flight, then fade
                      // out quickly over the last stretch.
                      opacity: 1 - ((e - 0.7) / 0.25).clamp(0.0, 1.0),
                      child: PlayingCardView(
                        card: const bj.Card(rank: 'A', suit: '♠', faceDown: true),
                        theme: widget.theme,
                        width: widget.width,
                        showShadow: false,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _TableCenter extends StatelessWidget {
  final eng.GameState game;
  final AppearanceTheme theme;
  final bool hasDealt;
  const _TableCenter({required this.game, required this.theme, required this.hasDealt});

  @override
  Widget build(BuildContext context) {
    if (game.phase == eng.GamePhase.complete && game.message.isNotEmpty) {
      final hasBlackjack = game.playerHands.any(
        (h) => h.result == eng.HandResult.blackjack,
      );
      final dealerBlackjack =
          game.dealerCards.length == 2 && bj.isBlackjack(game.dealerCards);
      final surrendered =
          game.playerHands.any((h) => h.result == eng.HandResult.surrender);
      final score = _handScore(game.playerHands);
      final split = game.playerHands.length > 1;
      final color = hasBlackjack
          ? theme.goldLight
          : score > 0
          ? const Color(0xFF6EE7B7)
          : score < 0
          ? const Color(0xFFFC8181)
          : AppTokens.textSecondary;
      final String headline;
      if (split) {
        final wins = game.playerHands
            .where((h) =>
                h.result == eng.HandResult.win || h.result == eng.HandResult.blackjack)
            .length;
        final losses = game.playerHands
            .where((h) =>
                h.result == eng.HandResult.lose || h.result == eng.HandResult.surrender)
            .length;
        headline = score > 0
            ? 'You win $wins of ${game.playerHands.length}'
            : score < 0
            ? 'You lose $losses of ${game.playerHands.length}'
            : 'Split — even';
      } else if (hasBlackjack) {
        headline = 'Blackjack!';
      } else if (surrendered) {
        headline = 'Surrendered';
      } else if (score > 0) {
        headline = 'You win!';
      } else if (score < 0) {
        headline = dealerBlackjack ? 'Dealer Blackjack' : 'You lose';
      } else {
        headline = dealerBlackjack ? 'Dealer Blackjack — push' : 'Push';
      }
      return AppearIn(
        triggerKey: headline,
        fromScale: 0.7,
        child: Text(
          headline,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      );
    }
    // The welcome branding only greets an untouched table; once a hand has been
    // played it stays out of the way.
    if (!hasDealt) {
      return Text(
        'Blackjack 101',
        style: TextStyle(
          color: theme.gold.withValues(alpha: 0.55),
          fontSize: 26,
          fontWeight: FontWeight.bold,
          fontFamily: 'serif',
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _PlayerZone extends StatelessWidget {
  final eng.GameState game;
  final AppearanceTheme theme;
  final double cardWidth;
  final int roundId;
  const _PlayerZone({
    required this.game,
    required this.theme,
    required this.cardWidth,
    required this.roundId,
  });

  @override
  Widget build(BuildContext context) {
    if (game.playerHands.isEmpty) return const SizedBox.shrink();
    final active = game.phase == eng.GamePhase.playerTurn;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < game.playerHands.length; i++)
            BlackjackHandView(
              cards: game.playerHands[i].cards,
              theme: theme,
              cardWidth: cardWidth,
              isActive: active && i == game.activeHandIndex,
              result: game.playerHands[i].result,
              roundId: roundId,
            ),
        ],
      ),
    );
  }
}

class _Controls extends ConsumerWidget {
  final GameStoreState store;
  final AppearanceTheme theme;
  const _Controls({required this.store, required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = store.game;
    final notifier = ref.read(gameProvider.notifier);

    return Container(
      height: 150,
      width: double.infinity,
      color: theme.feltDark,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.14),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey(game.phase),
              child: switch (game.phase) {
                eng.GamePhase.betting => _DealPanel(
                  theme: theme,
                  notifier: notifier,
                ),
                eng.GamePhase.playerTurn => _ActionBar(
                  notifier: notifier,
                  theme: theme,
                ),
                eng.GamePhase.complete => _CompleteActions(
                  theme: theme,
                  notifier: notifier,
                ),
                _ => const SizedBox.shrink(),
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _DealPanel extends StatelessWidget {
  final AppearanceTheme theme;
  final GameController notifier;
  const _DealPanel({
    required this.theme,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GameButton(
        label: 'Deal',
        theme: theme,
        variant: GameBtn.gold,
        onPressed: notifier.deal,
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final GameController notifier;
  final AppearanceTheme theme;
  const _ActionBar({required this.notifier, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: GameButton(
                label: 'Hit',
                theme: theme,
                variant: GameBtn.gold,
                expand: true,
                onPressed: notifier.hit,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GameButton(
                label: 'Stand',
                theme: theme,
                variant: GameBtn.gold,
                expand: true,
                onPressed: notifier.stand,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GameButton(
                label: 'Double',
                theme: theme,
                expand: true,
                onPressed: notifier.canDouble ? notifier.double : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GameButton(
                label: 'Split',
                theme: theme,
                expand: true,
                onPressed: notifier.canSplit ? notifier.split : null,
              ),
            ),
            if (notifier.canSurrender) ...[
              const SizedBox(width: 8),
              Expanded(
                child: GameButton(
                  label: 'Surrender',
                  theme: theme,
                  expand: true,
                  onPressed: notifier.surrender,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: withHaptic(
            () => _confirmAction(
              context,
              title: 'Forfeit this hand?',
              message: 'The current hand ends without being scored.',
              confirmLabel: 'Forfeit',
              onConfirm: notifier.forfeitHand,
            ),
          ),
          child: Text(
            'Forfeit hand',
            style: TextStyle(color: AppTokens.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _CompleteActions extends StatelessWidget {
  final AppearanceTheme theme;
  final GameController notifier;
  const _CompleteActions({
    required this.theme,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    final newSessionButton = TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: withHaptic(
        () => _confirmAction(
          context,
          title: 'Start a new session?',
          message:
              'This ends your current session and resets the table. '
              'Your stats are saved.',
          confirmLabel: 'New Session',
          onConfirm: notifier.newSession,
        ),
      ),
      child: Text(
        'New Session',
        style: TextStyle(color: AppTokens.textSecondary),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GameButton(
          label: 'Deal Again',
          theme: theme,
          variant: GameBtn.gold,
          onPressed: notifier.rebetAndDeal,
        ),
        const SizedBox(height: 6),
        newSessionButton,
      ],
    );
  }
}

class _StrategyHint extends ConsumerWidget {
  final LastHandInfo info;
  final AppearanceTheme theme;
  const _StrategyHint({required this.info, required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final correct = info.wasCorrect;
    final locked = !ref.watch(proStatusProvider).isPro;
    return GestureDetector(
      onTap: withHaptic(
        () => showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: Text(
              correct ? 'Optimal play ✓' : 'Optimal: ${info.optimal.label}',
            ),
            content: locked
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline, size: 18, color: theme.goldLight),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Unlock the reasoning behind every play to learn faster.',
                          style: TextStyle(color: AppTokens.textSecondary, height: 1.4),
                        ),
                      ),
                    ],
                  )
                : Text(info.optimal.explanation),
            actions: locked
                ? [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogCtx),
                      child: const Text('Not now'),
                    ),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(dialogCtx);
                        openGoPro(context);
                      },
                      child: const Text('Go Pro'),
                    ),
                  ]
                : [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogCtx),
                      child: const Text('Got it'),
                    ),
                  ],
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: correct ? const Color(0x3327AE60) : const Color(0x33C0392B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: correct ? const Color(0xFF27AE60) : const Color(0xFFC0392B),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                correct
                    ? '✓ Optimal play'
                    : '✕ Should have ${info.optimal.label.toLowerCase()}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: correct ? const Color(0xFF6EE7B7) : const Color(0xFFFC8181),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (locked) ...[
              const SizedBox(width: 5),
              Icon(
                Icons.lock_outline,
                size: 12,
                color: correct ? const Color(0xFF6EE7B7) : const Color(0xFFFC8181),
              ),
            ] else if (!correct) ...[
              const SizedBox(width: 5),
              Icon(
                Icons.info_outline,
                size: 13,
                color: const Color(0xFFFC8181),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
