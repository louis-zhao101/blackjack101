import 'dart:math' show pi;
import 'dart:ui' show ImageFilter;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/achievements.dart';
import '../../engine/stats.dart';
import '../../engine/strategy.dart' as st;
import '../../state/achievements_provider.dart';
import '../../state/appearance_provider.dart';
import '../../state/auth_provider.dart';
import '../../state/stats_provider.dart';
import '../../state/store_provider.dart';
import '../auth_screen.dart';
import '../theme/appearance.dart';
import '../widgets/game_button.dart';
import '../widgets/strategy_chart.dart';
import 'shop_page.dart';

const _good = Color(0xFF6EE7B7);
const _ok = Color(0xFFF0C84A);
const _warn = Color(0xFFFC8181);

// Match the Account page's grouped-card look.
const _cardBg = Color(0x14FFFFFF);
const _tileBg = Color(0x24FFFFFF);
const _divider = Color(0x12FFFFFF);

const _recentLimit = 5;
const _freeHistoryLimit = 3;
const _chartWindow = 10;

String _actionName(st.Action a) => switch (a) {
      st.Action.hit => 'Hit',
      st.Action.stand => 'Stand',
      st.Action.double => 'Double',
      st.Action.split => 'Split',
      st.Action.surrender => 'Surrender',
    };

Color _accColor(double pct) => pct >= 80 ? _good : (pct >= 60 ? _ok : _warn);

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loggedIn = ref.watch(authStateProvider).value != null;
    if (!loggedIn) return const _StatsSignInGate();

    final theme = ref.watch(appearanceProvider);
    final isPremium = ref.watch(entitlementsProvider).isPremium;
    final stats = ref.watch(statsProvider);
    final hasLive = stats.currentSession != null && stats.currentSession!.hands.isNotEmpty;
    final allSessions = [
      ...stats.sessions,
      if (hasLive) stats.currentSession!,
    ];

    if (allSessions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Play some hands to see your stats here.',
              style: TextStyle(color: AppTokens.textSecondary, fontSize: 16)),
        ),
      );
    }

    final summaries = allSessions.map(summarizeSession).toList();
    // Session history is newest-first by start date (the live session, being the
    // most recently started, naturally sorts to the top).
    final recentFirst = [...summaries]..sort((a, b) => b.date.compareTo(a.date));
    final mistakes = getCommonMistakes(allSessions);
    final categories = getMistakeCategories(allSessions);

    final allHands = allSessions.expand((s) => s.hands).toList();
    final totalHands = allHands.length;
    final overallAccuracy =
        totalHands > 0 ? (allHands.where((h) => h.wasCorrect).length / totalHands * 100).round() : 0;
    final totalPL = summaries.fold<int>(0, (a, s) => a + s.profitLoss);
    final bestStreak = computeLongestStreak(allHands);
    final eligible = summaries.where((s) => s.handsPlayed >= 5).map((s) => s.correctPct);
    final bestSession = eligible.isEmpty ? 0.0 : eligible.reduce((a, b) => a > b ? a : b);

    final historyLimit = isPremium ? _recentLimit : _freeHistoryLimit;
    final shownSessions = recentFirst.take(historyLimit).toList();
    final hiddenSessions = recentFirst.length - shownSessions.length;
    final topMistakes = mistakes.take(5).toList();

    // Chart shows only the most recent sessions so the axis stays readable.
    final chartSummaries = summaries.length > _chartWindow
        ? summaries.sublist(summaries.length - _chartWindow)
        : summaries;
    final chartStart = summaries.length - chartSummaries.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        _Section(
          title: 'Overview',
          children: [
            _StatRow(icon: Icons.style_outlined, label: 'Total hands', value: '$totalHands'),
            _StatRow(
              icon: Icons.track_changes,
              label: 'Overall accuracy',
              value: '$overallAccuracy%',
              valueColor: _accColor(overallAccuracy.toDouble()),
            ),
            _StatRow(
              icon: Icons.local_fire_department_outlined,
              label: 'Best streak',
              value: '$bestStreak',
              valueColor: bestStreak >= 10 ? _good : (bestStreak >= 5 ? _ok : null),
            ),
            _StatRow(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Total P&L',
              value: '${totalPL >= 0 ? '+' : ''}\$$totalPL',
              valueColor: totalPL >= 0 ? _good : _warn,
            ),
            _StatRow(icon: Icons.history, label: 'Sessions', value: '${stats.sessions.length}'),
            if (bestSession > 0)
              _StatRow(
                icon: Icons.emoji_events_outlined,
                label: 'Best session',
                value: '${bestSession.toStringAsFixed(0)}%',
                valueColor: bestSession >= 90 ? _good : _ok,
              ),
          ],
        ),
        const SizedBox(height: 16),
        const _AchievementsSection(),
        if (recentFirst.length > 1) ...[
          const SizedBox(height: 16),
          _Section(
            title: 'Accuracy over sessions',
            trailing: isPremium && summaries.length > _chartWindow
                ? const Text('last $_chartWindow',
                    style: TextStyle(color: AppTokens.textSecondary, fontSize: 12))
                : null,
            children: [
              if (isPremium)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    height: 200,
                    child: _AccuracyChart(
                        summaries: chartSummaries, startIndex: chartStart, color: theme.gold),
                  ),
                )
              else
                _LockedPreview(
                  theme: theme,
                  label: 'See your accuracy trend',
                  sublabel: 'Track how you improve across every session.',
                  onTap: () => openGoPro(context),
                  previewHeight: 200,
                  preview: SizedBox(
                    height: 200,
                    child: _AccuracyChart(
                        summaries: chartSummaries, startIndex: chartStart, color: theme.gold),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        _Section(
          title: 'Strategy accuracy',
          children: [
            if (isPremium) ...[
              const Padding(
                padding: EdgeInsets.only(left: 2, top: 2, bottom: 8),
                child: Text(
                  'How often you play each hand correctly vs the dealer upcard. Tap a cell for details.',
                  style: TextStyle(color: AppTokens.textSecondary, fontSize: 12.5, height: 1.4),
                ),
              ),
              StrategyChart(accuracy: ref.watch(strategyStatsProvider)),
            ] else
              _LockedPreview(
                theme: theme,
                label: 'See your strategy accuracy',
                sublabel: 'A heatmap of how often you play each hand right.',
                onTap: () => openGoPro(context),
                previewHeight: 300,
                preview: StrategyChart(accuracy: ref.watch(strategyStatsProvider)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Session history',
          trailing: Text('${recentFirst.length} total',
              style: const TextStyle(color: AppTokens.textSecondary, fontSize: 12)),
          children: [
            for (var i = 0; i < shownSessions.length; i++) ...[
              if (i > 0) const _Divider(),
              _SessionTile(s: shownSessions[i], theme: theme),
            ],
            if (hiddenSessions > 0) ...[
              const _Divider(),
              if (isPremium)
                _StatRow(
                  icon: Icons.unfold_more,
                  label: 'View all ${recentFirst.length} sessions',
                  onTap: () => _showAllSessions(context, theme, recentFirst),
                )
              else
                _StatRow(
                  icon: Icons.lock_outline,
                  label: 'Unlock full history ($hiddenSessions more)',
                  value: 'Pro',
                  valueColor: theme.goldLight,
                  onTap: () => openGoPro(context),
                ),
            ],
          ],
        ),
        if (categories.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Section(
            title: 'Common mistakes',
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: SizedBox(
                  height: 220,
                  child: _MistakesChart(categories: categories.take(5).toList(), color: theme.gold),
                ),
              ),
              for (final m in topMistakes) ...[
                const _Divider(),
                _MistakeTile(
                  m: m,
                  unlocked: isPremium,
                  onLockedTap: () => openGoPro(context),
                ),
              ],
            ],
          ),
        ],
        const SizedBox(height: 16),
        _Section(
          title: 'Manage',
          children: [
            _StatRow(
              icon: Icons.delete_sweep_outlined,
              label: 'Clear history',
              danger: true,
              onTap: () => _confirmClear(context, ref),
            ),
          ],
        ),
      ],
    );
  }

  void _showAllSessions(BuildContext context, AppearanceTheme theme, List<SessionSummary> sessions) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(
          color: theme.feltDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(color: theme.feltBorder),
            left: BorderSide(color: theme.feltBorder),
            right: BorderSide(color: theme.feltBorder),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTokens.textSecondary.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Padding(
                  padding: EdgeInsets.only(left: 2, bottom: 6),
                  child: Text('All sessions',
                      style: TextStyle(
                          color: AppTokens.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: sessions.length,
                    separatorBuilder: (_, _) => const _Divider(),
                    itemBuilder: (_, i) => _SessionTile(s: sessions[i], theme: theme),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmClear(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear stats history?'),
        content: const Text(
            'This removes all saved sessions and your strategy accuracy. Practice '
            'drills and earned achievements are kept. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: withHaptic(() => Navigator.pop(context)),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: withHaptic(() {
              ref.read(statsProvider.notifier).clearHistory();
              Navigator.pop(context);
            }),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _AchievementsSection extends ConsumerStatefulWidget {
  const _AchievementsSection();

  @override
  ConsumerState<_AchievementsSection> createState() => _AchievementsSectionState();
}

class _AchievementsSectionState extends ConsumerState<_AchievementsSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(appearanceProvider);
    final statuses = ref.watch(achievementStatusesProvider);
    final unlocked = statuses.where((s) => s.unlocked).length;

    return _Section(
      title: 'Achievements',
      trailing: Text('$unlocked/${statuses.length}',
          style: TextStyle(color: theme.goldLight, fontSize: 12, fontWeight: FontWeight.w600)),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 12.0;
              final cols = (constraints.maxWidth / 84).floor().clamp(4, 6).toInt();
              final itemWidth = (constraints.maxWidth - spacing * (cols - 1)) / cols;
              final hasMore = statuses.length > cols;
              final visible = _expanded ? statuses : statuses.take(cols).toList();
              return Column(
                children: [
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: Wrap(
                      spacing: spacing,
                      runSpacing: 18,
                      children: [
                        for (final s in visible)
                          SizedBox(
                            width: itemWidth,
                            child: _AchievementBadge(
                              status: s,
                              theme: theme,
                              onTap: () => _showAchievement(context, theme, s),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (hasMore)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: withHaptic(() => setState(() => _expanded = !_expanded)),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 14, bottom: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_expanded ? 'Show less' : 'Show all ${statuses.length}',
                                style: TextStyle(
                                    color: theme.goldLight,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(width: 2),
                            AnimatedRotation(
                              turns: _expanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(Icons.expand_more, color: theme.goldLight, size: 20),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAchievement(BuildContext context, AppearanceTheme theme, AchievementStatus s) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: theme.feltDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(color: theme.feltBorder),
            left: BorderSide(color: theme.feltBorder),
            right: BorderSide(color: theme.feltBorder),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTokens.textSecondary.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: _DiamondBadge(
                    emoji: s.achievement.emoji,
                    unlocked: s.unlocked,
                    theme: theme,
                    size: 66,
                    emojiSize: 34,
                  ),
                ),
                const SizedBox(height: 14),
                Text(s.achievement.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppTokens.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(s.achievement.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppTokens.textSecondary, fontSize: 14, height: 1.4)),
                const SizedBox(height: 18),
                if (s.unlocked)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: _good, size: 18),
                      const SizedBox(width: 6),
                      const Text('Unlocked',
                          style: TextStyle(
                              color: _good, fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  )
                else ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: s.fraction,
                      minHeight: 7,
                      backgroundColor: _tileBg,
                      valueColor: AlwaysStoppedAnimation(theme.gold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('${s.shownCurrent} / ${s.target}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppTokens.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AchievementBadge extends StatelessWidget {
  final AchievementStatus status;
  final AppearanceTheme theme;
  final VoidCallback onTap;
  const _AchievementBadge(
      {required this.status, required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final unlocked = status.unlocked;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: withHaptic(onTap),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DiamondBadge(
            emoji: status.achievement.emoji,
            unlocked: unlocked,
            theme: theme,
            size: 46,
            emojiSize: 24,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 26,
            child: Text(
              status.achievement.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: unlocked ? AppTokens.textPrimary : AppTokens.textSecondary,
                fontSize: 10,
                height: 1.2,
                fontWeight: unlocked ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A gem-cut badge: a rounded square rotated to a diamond, with the emoji kept
/// upright. Unlocked badges get a gold gradient fill and a soft glow.
class _DiamondBadge extends StatelessWidget {
  final String emoji;
  final bool unlocked;
  final AppearanceTheme theme;
  final double size;
  final double emojiSize;
  const _DiamondBadge({
    required this.emoji,
    required this.unlocked,
    required this.theme,
    required this.size,
    required this.emojiSize,
  });

  @override
  Widget build(BuildContext context) {
    final box = size * 1.42;
    return Opacity(
      opacity: unlocked ? 1 : 0.32,
      child: SizedBox(
        width: box,
        height: box,
        child: Center(
          child: Transform.rotate(
            angle: pi / 4,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: unlocked ? theme.gold.withValues(alpha: 0.18) : _tileBg,
                borderRadius: BorderRadius.circular(size * 0.24),
                border: Border.all(
                  color: unlocked ? theme.gold : const Color(0x1AFFFFFF),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Transform.rotate(
                  angle: -pi / 4,
                  child: Text(emoji, style: TextStyle(fontSize: emojiSize)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final List<Widget> children;
  const _Section({required this.title, this.trailing, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 4),
            child: Row(
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppTokens.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                if (trailing != null) ...[const Spacer(), trailing!],
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: _divider, margin: const EdgeInsets.symmetric(vertical: 2));
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Color? valueColor;
  final VoidCallback? onTap;
  final bool danger;
  const _StatRow({
    required this.icon,
    required this.label,
    this.value,
    this.valueColor,
    this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = danger ? _warn : AppTokens.textPrimary;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: _tileBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: TextStyle(color: fg, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          if (value != null)
            Text(value!,
                style: TextStyle(
                    color: valueColor ?? AppTokens.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold))
          else if (onTap != null)
            const Icon(Icons.chevron_right, color: AppTokens.textSecondary, size: 20),
        ],
      ),
    );
    if (onTap == null) return row;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: withHaptic(onTap), child: row);
  }
}

class _SessionTile extends StatelessWidget {
  final SessionSummary s;
  final AppearanceTheme theme;
  const _SessionTile({required this.s, required this.theme});

  @override
  Widget build(BuildContext context) {
    final accColor = _accColor(s.correctPct);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (s.isLive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration:
                      BoxDecoration(color: theme.gold, borderRadius: BorderRadius.circular(12)),
                  child: Text('LIVE',
                      style: TextStyle(
                          color: theme.feltDark, fontSize: 10, fontWeight: FontWeight.bold)),
                )
              else
                Text(_date(s.date),
                    style: const TextStyle(
                        color: AppTokens.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                '${s.profitLoss >= 0 ? '+' : ''}\$${s.profitLoss}',
                style: TextStyle(
                    color: s.profitLoss >= 0 ? _good : _warn,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Text('${s.handsPlayed} hands',
                  style: const TextStyle(color: AppTokens.textSecondary, fontSize: 12)),
              const Text('  ·  ', style: TextStyle(color: AppTokens.textSecondary, fontSize: 12)),
              Text('${s.correctCount}/${s.handsPlayed} · ${s.correctPct.toStringAsFixed(0)}%',
                  style: TextStyle(color: accColor, fontSize: 12, fontWeight: FontWeight.w600)),
              if (s.longestStreak >= 10)
                Text('  🔥${s.longestStreak}',
                    style: const TextStyle(color: _ok, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  String _date(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.month}/${d.day}/${d.year}';
  }
}

class _MistakeTile extends StatefulWidget {
  final MistakeSummary m;
  final bool unlocked;
  final VoidCallback onLockedTap;
  const _MistakeTile(
      {required this.m, required this.unlocked, required this.onLockedTap});

  @override
  State<_MistakeTile> createState() => _MistakeTileState();
}

class _MistakeTileState extends State<_MistakeTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    final kind = m.soft ? 'Soft ' : (m.handType == st.HandType.pair ? 'Pair of ' : 'Hard ');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: withHaptic(() {
        if (widget.unlocked) {
          setState(() => _expanded = !_expanded);
        } else {
          widget.onLockedTap();
        }
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                                color: const Color(0x33E74C3C),
                                borderRadius: BorderRadius.circular(12)),
                            child: Text('${m.count}×',
                                style: const TextStyle(
                                    color: _warn, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('$kind${m.playerTotal} vs dealer ${m.dealerUpcard}',
                                style: const TextStyle(
                                    color: AppTokens.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                          'Played ${_actionName(m.playerAction)} → should ${_actionName(m.optimalAction)}',
                          style: TextStyle(color: classicGreen.goldLight, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (widget.unlocked)
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.expand_more, color: AppTokens.textSecondary, size: 20),
                  )
                else
                  Icon(Icons.lock_outline, color: classicGreen.goldLight, size: 17),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: widget.unlocked && _expanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(m.explanation,
                          style: const TextStyle(
                              color: AppTokens.textSecondary, height: 1.4, fontSize: 12.5)),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tappable "this is Premium" panel used inside a stats section.
/// Premium gate that shows the real [preview] content behind a blur + scrim, so
/// users get a teaser of what Pro unlocks. Clipped to [previewHeight].
class _LockedPreview extends StatelessWidget {
  final AppearanceTheme theme;
  final String label;
  final String sublabel;
  final VoidCallback onTap;
  final Widget preview;
  final double previewHeight;
  const _LockedPreview({
    required this.theme,
    required this.label,
    required this.sublabel,
    required this.onTap,
    required this.preview,
    required this.previewHeight,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: withHaptic(onTap),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: radius),
        child: SizedBox(
          width: double.infinity,
          height: previewHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Real content, rendered at natural size and clipped, non-interactive.
              IgnorePointer(
                child: OverflowBox(
                  alignment: Alignment.topCenter,
                  minHeight: 0,
                  maxHeight: double.infinity,
                  child: Padding(padding: const EdgeInsets.all(6), child: preview),
                ),
              ),
              // Blur + scrim + unlock CTA.
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: theme.feltDark.withValues(alpha: 0.5),
                    borderRadius: radius,
                    border: Border.all(color: theme.gold.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline, color: theme.goldLight, size: 26),
                      const SizedBox(height: 8),
                      Text(label,
                          style: const TextStyle(
                              color: AppTokens.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                      const SizedBox(height: 3),
                      Text(sublabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppTokens.textSecondary, fontSize: 12, height: 1.3)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                            color: theme.gold, borderRadius: BorderRadius.circular(10)),
                        child: Text('Unlock with Pro',
                            style: TextStyle(
                                color: theme.feltDark,
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsSignInGate extends StatelessWidget {
  const _StatsSignInGate();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.insights_outlined, size: 56, color: AppTokens.textSecondary),
              const SizedBox(height: 16),
              const Text(
                'Track your progress',
                style: TextStyle(
                    color: AppTokens.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign in to save your hands and see accuracy, streaks, and your most common mistakes.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTokens.textSecondary, fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: withHaptic(() => showSignInSheet(context)),
                child: const Text('Sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccuracyChart extends StatelessWidget {
  final List<SessionSummary> summaries;
  final int startIndex;
  final Color color;
  const _AccuracyChart(
      {required this.summaries, required this.startIndex, required this.color});

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (var i = 0; i < summaries.length; i++) FlSpot(i.toDouble(), summaries[i].correctPct),
    ];
    // Anchor labels at the last point and step backward so they never collide.
    final step = (summaries.length / 5).ceil();
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: Color(0x14FFFFFF), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => const Color(0xF20E1A13),
            tooltipBorderRadius: BorderRadius.circular(8),
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            getTooltipItems: (spots) => spots.map((s) {
              final i = s.x.toInt();
              final label = (i >= 0 && i < summaries.length && summaries[i].isLive)
                  ? 'Now'
                  : 'S${startIndex + i + 1}';
              return LineTooltipItem(
                '$label\n${s.y.toStringAsFixed(0)}%',
                TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
              );
            }).toList(),
          ),
          getTouchedSpotIndicator: (bar, indexes) => indexes
              .map((_) => TouchedSpotIndicatorData(
                    FlLine(color: color.withValues(alpha: 0.45), strokeWidth: 1),
                    FlDotData(
                      getDotPainter: (s, _, _, _) => FlDotCirclePainter(
                        radius: 4,
                        color: color,
                        strokeColor: const Color(0xFF0E1A13),
                        strokeWidth: 2,
                      ),
                    ),
                  ))
              .toList(),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              interval: 25,
              getTitlesWidget: (v, _) => Text('${v.toInt()}%',
                  style: const TextStyle(color: AppTokens.textSecondary, fontSize: 10)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= summaries.length) return const SizedBox.shrink();
                if ((summaries.length - 1 - i) % step != 0) return const SizedBox.shrink();
                final label = summaries[i].isLive ? 'Now' : 'S${startIndex + i + 1}';
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(label,
                      style: const TextStyle(color: AppTokens.textSecondary, fontSize: 10)),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            preventCurveOverShooting: true,
            color: color,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, _, _) =>
                  FlDotCirclePainter(radius: 3, color: color, strokeWidth: 0),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.0)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MistakesChart extends StatelessWidget {
  final List<MistakeCategory> categories;
  final Color color;
  const _MistakesChart({required this.categories, required this.color});

  @override
  Widget build(BuildContext context) {
    final maxCount = categories.fold<int>(0, (m, c) => c.count > m ? c.count : m);
    final stepRaw = (maxCount / 4).ceil();
    final step = stepRaw < 1 ? 1 : stepRaw;
    final maxY = ((maxCount ~/ step) + 1) * step;
    return BarChart(
      BarChartData(
        maxY: maxY.toDouble(),
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: step.toDouble(),
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: Color(0x14FFFFFF), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => const Color(0xF20E1A13),
            tooltipBorderRadius: BorderRadius.circular(8),
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            getTooltipItem: (group, _, rod, _) {
              final c = categories[group.x.toInt()];
              return BarTooltipItem(
                '${c.label}\n${c.count}×',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: step.toDouble(),
              getTitlesWidget: (v, _) => Text('${v.toInt()}',
                  style: const TextStyle(color: AppTokens.textSecondary, fontSize: 10)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= categories.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    width: 62,
                    child: Text(categories[i].label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppTokens.textSecondary, fontSize: 9, height: 1.2)),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < categories.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: categories[i].count.toDouble(),
                width: 26,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color, color.withValues(alpha: 0.06)],
                ),
              ),
            ]),
        ],
      ),
    );
  }
}
