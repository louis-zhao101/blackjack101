import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/engine.dart' as eng;
import '../../engine/variants.dart';
import '../../state/appearance_provider.dart';
import '../../state/game_provider.dart';
import '../../state/settings_provider.dart';
import '../../state/stats_provider.dart';
import '../theme/appearance.dart';
import '../widgets/bet_chip_stack.dart';
import '../widgets/blackjack_hand.dart';
import '../widgets/chip_widget.dart';
import '../widgets/game_button.dart';

const _chipDenoms = [5, 25, 100, 500];

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

void _showRuleInfo(BuildContext context, AppearanceTheme theme, RuleSet r) {
  HapticFeedback.selectionClick();
  final lines = ruleSetDescription(r).split('\n');
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(r.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_outline, size: 16, color: theme.gold),
                  const SizedBox(width: 8),
                  Expanded(child: Text(line)),
                ],
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: withHaptic(() => Navigator.pop(context)),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class PlayPage extends ConsumerWidget {
  const PlayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appearanceProvider);
    final store = ref.watch(gameProvider);
    final game = store.game;
    // Before the first deal, show the pending ruleset's payout; after, use the locked game ruleset.
    final effectivePayout = store.hasDealtInSession
        ? game.ruleSet.blackjackPays
        : ref.watch(settingsProvider).ruleSet.blackjackPays;

    return Column(
      children: [
        _StatsBar(store: store, theme: theme),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth < 480
                  ? 52.0
                  : constraints.maxWidth < 900
                  ? 68.0
                  : 80.0;
              final bet = game.phase == eng.GamePhase.betting
                  ? game.pendingBet
                  : game.playerHands.fold<int>(0, (s, h) => s + h.bet);
              return Container(
                width: double.infinity,
                decoration: BoxDecoration(gradient: theme.feltGradient),
                padding: const EdgeInsets.all(16),
                child: Stack(
                  children: [
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
                            child: _TableCenter(game: game, theme: theme, payout: effectivePayout),
                          ),
                        ),
                        _PlayerZone(
                          game: game,
                          theme: theme,
                          cardWidth: cardWidth,
                          roundId: store.roundId,
                        ),
                        SizedBox(
                          height: 36,
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
                    if (bet > 0)
                      Positioned(
                        right: 4,
                        bottom: 8,
                        child: BetChipStack(
                          amount: bet,
                          theme: theme,
                          settle: game.phase == eng.GamePhase.complete
                              ? (game.playerHands.fold<int>(
                                          0, (s, h) => s + h.payout - h.bet) <
                                      0
                                  ? ChipSettle.toDealer
                                  : ChipSettle.toPlayer)
                              : null,
                        ),
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
    final game = store.game;
    final bet = game.phase == eng.GamePhase.betting
        ? game.pendingBet
        : game.playerHands.fold<int>(0, (sum, h) => sum + h.bet);
    final handsPlayed =
        ref.watch(statsProvider).currentSession?.hands.length ?? 0;
    final plays = store.playStats;
    final hasPlays = plays.total > 0;
    final pct = hasPlays ? (plays.correct / plays.total * 100).round() : 0;
    final pctColor = pct >= 80
        ? const Color(0xFF6EE7B7)
        : pct >= 60
        ? theme.goldLight
        : const Color(0xFFFC8181);

    final settings = ref.watch(settingsProvider);
    final currentRuleSet = settings.ruleSet;
    final ruleSetLocked = store.hasDealtInSession;

    return Container(
      width: double.infinity,
      color: theme.feltDark,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            PopupMenuButton<String>(
              tooltip: 'Game mode',
              position: PopupMenuPosition.under,
              onSelected: (id) {
                HapticFeedback.selectionClick();
                if (id == currentRuleSet.id) return;
                final rule = rulePresets.firstWhere((r) => r.id == id);
                if (ruleSetLocked) {
                  _confirmAction(
                    context,
                    title: 'Switch game mode?',
                    message:
                        'Switching to ${rule.name} starts a new session and '
                        'resets the current hand.',
                    confirmLabel: 'Switch',
                    onConfirm: () {
                      ref.read(settingsProvider.notifier).setRuleSet(rule);
                      ref.read(gameProvider.notifier).newSession();
                    },
                  );
                } else {
                  ref.read(settingsProvider.notifier).setRuleSet(rule);
                }
              },
              itemBuilder: (_) => [
                for (final r in rulePresets)
                  PopupMenuItem<String>(
                    value: r.id,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 22,
                          child: r.id == currentRuleSet.id
                              ? Icon(Icons.check, size: 16, color: theme.gold)
                              : null,
                        ),
                        Text(r.name),
                        const SizedBox(width: 6),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _showRuleInfo(context, theme, r),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(Icons.info_outline,
                                size: 15, color: AppTokens.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currentRuleSet.name,
                    style: TextStyle(
                      color: theme.goldLight,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(Icons.expand_more, size: 16, color: AppTokens.textSecondary),
                ],
              ),
            ),
            _divider(),
            _item('BALANCE', '\$${game.bankroll}', theme.goldLight),
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              icon: Icon(Icons.add_circle_outline, color: AppTokens.textSecondary),
              tooltip: 'Add chips',
              onPressed: withHaptic(() => _addChips(context, ref)),
            ),
            _divider(),
            _item('BET', '\$$bet', AppTokens.textPrimary),
            if (hasPlays) ...[
              _divider(),
              _item('ACCURACY', '$pct% (${plays.correct}/${plays.total})', pctColor),
              _divider(),
              _item('HANDS', '$handsPlayed', AppTokens.textPrimary),
            ],
          ],
        ),
      ),
    );
  }

  Widget _item(String label, String value, Color color) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: Row(
      children: [
        Text(
          '$label ',
          style: const TextStyle(
            color: AppTokens.textSecondary,
            fontSize: 11,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );

  Widget _divider() => Container(
    width: 1,
    height: 18,
    margin: const EdgeInsets.symmetric(horizontal: 8),
    color: const Color(0x22FFFFFF),
  );

  void _addChips(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add chips'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            prefixText: '\$ ',
            hintText: 'Amount',
          ),
          onSubmitted: (_) => _submitChips(context, ref, controller.text),
        ),
        actions: [
          TextButton(
            onPressed: withHaptic(() => Navigator.pop(context)),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: withHaptic(
              () => _submitChips(context, ref, controller.text),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _submitChips(BuildContext context, WidgetRef ref, String text) {
    final n = int.tryParse(text.trim());
    if (n != null && n > 0) {
      ref.read(gameProvider.notifier).topUp(n);
    }
    Navigator.pop(context);
  }
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
        const SizedBox(height: 4),
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

class _TableCenter extends StatelessWidget {
  final eng.GameState game;
  final AppearanceTheme theme;
  final BlackjackPayout payout;
  const _TableCenter({required this.game, required this.theme, required this.payout});

  @override
  Widget build(BuildContext context) {
    if (game.phase == eng.GamePhase.complete && game.message.isNotEmpty) {
      final hasBlackjack = game.playerHands.any(
        (h) => h.result == eng.HandResult.blackjack,
      );
      final net = game.playerHands.fold<int>(0, (s, h) => s + h.payout - h.bet);
      final color = hasBlackjack
          ? theme.goldLight
          : net > 0
          ? const Color(0xFF6EE7B7)
          : net < 0
          ? const Color(0xFFFC8181)
          : AppTokens.textSecondary;
      return AppearIn(
        triggerKey: game.message,
        fromScale: 0.7,
        child: Text(
          game.message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Blackjack 101',
          style: TextStyle(
            color: theme.gold.withValues(alpha: 0.55),
            fontSize: 26,
            fontWeight: FontWeight.bold,
            fontFamily: 'serif',
          ),
        ),
        Text(
          switch (payout) {
            BlackjackPayout.sixToFive => 'PAYS 6 TO 5',
            BlackjackPayout.oneToOne => 'PAYS 1 TO 1',
            _ => 'PAYS 3 TO 2',
          },
          style: TextStyle(
            color: theme.gold.withValues(alpha: 0.4),
            fontSize: 11,
            letterSpacing: 3,
          ),
        ),
      ],
    );
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
                eng.GamePhase.betting => _BetPanel(
                  game: game,
                  theme: theme,
                  notifier: notifier,
                ),
                eng.GamePhase.playerTurn => _ActionBar(
                  notifier: notifier,
                  theme: theme,
                ),
                eng.GamePhase.complete => _CompleteActions(
                  game: game,
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

class _BetPanel extends StatelessWidget {
  final eng.GameState game;
  final AppearanceTheme theme;
  final GameController notifier;
  const _BetPanel({
    required this.game,
    required this.theme,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 12,
          children: [
            for (final d in _chipDenoms)
              ChipWidget(
                amount: d,
                theme: theme,
                onTap: (game.pendingBet + d <= game.bankroll)
                    ? () => notifier.placeBetChip(d)
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GameButton(
              label: 'Clear',
              theme: theme,
              onPressed: game.pendingBet > 0 ? notifier.clearBet : null,
            ),
            SizedBox(
              width: 88,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'BET',
                    style: TextStyle(
                      color: AppTokens.textSecondary,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    '\$${game.pendingBet}',
                    style: TextStyle(
                      color: theme.goldLight,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            GameButton(
              label: 'Deal',
              theme: theme,
              variant: GameBtn.gold,
              onPressed: game.pendingBet >= 1 ? notifier.deal : null,
            ),
          ],
        ),
      ],
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
              message: 'Your current bet is returned and the hand ends.',
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
  final eng.GameState game;
  final AppearanceTheme theme;
  final GameController notifier;
  const _CompleteActions({
    required this.game,
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

    if (game.bankroll < 1) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Out of chips!',
            style: TextStyle(color: AppTokens.textPrimary, fontSize: 16),
          ),
          const SizedBox(height: 8),
          GameButton(
            label: 'Add \$500',
            theme: theme,
            variant: GameBtn.gold,
            onPressed: () => notifier.topUp(500),
          ),
          const SizedBox(height: 6),
          newSessionButton,
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            GameButton(
              label: 'Deal Again',
              theme: theme,
              variant: GameBtn.gold,
              onPressed: notifier.rebetAndDeal,
            ),
            GameButton(
              label: 'Change Bet',
              theme: theme,
              onPressed: notifier.nextHand,
            ),
          ],
        ),
        const SizedBox(height: 6),
        newSessionButton,
      ],
    );
  }
}

class _StrategyHint extends StatelessWidget {
  final LastHandInfo info;
  final AppearanceTheme theme;
  const _StrategyHint({required this.info, required this.theme});

  @override
  Widget build(BuildContext context) {
    final correct = info.wasCorrect;
    return GestureDetector(
      onTap: withHaptic(
        () => showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(
              correct ? 'Optimal play ✓' : 'Optimal: ${info.optimal.label}',
            ),
            content: Text(info.optimal.explanation),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
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
            if (!correct) ...[
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
